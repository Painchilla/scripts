#!/bin/bash
REAL_SMARTCTL="/root/spindown/smartctl.real"
CACHE_DIR="/dev/shm/smartctl_cache"

# Ziel-Laufwerk aus den Argumenten ermitteln (/dev/sd*)
DISK=""
for arg in "$@"; do
    if [[ "$arg" =~ ^/dev/sd[a-z]+$ ]]; then
        DISK="$arg"
        break
    fi
done

DEV_NAME=$(basename "$DISK")

# Nicht-SATA, NVMe oder SATA-SSDs (rotational == 0) direkt ungefiltert durchleiten
if [ -z "$DISK" ] || [ ! -f "$REAL_SMARTCTL" ] || [ "$(cat /sys/block/$DEV_NAME/queue/rotational 2>/dev/null)" = "0" ]; then
    exec "$REAL_SMARTCTL" "$@"
fi

# Prüfen, ob die Platte im Standby ist
IS_STANDBY=0
STATE=$(hdparm -C "$DISK" 2>/dev/null | grep -i "drive state is:" | awk '{print $NF}')

if [ "$STATE" = "standby" ] || [ "$STATE" = "sleeping" ]; then
    IS_STANDBY=1
else
    # Fallback für HBAs: smartctl mit -n standby weckt die Platte nicht auf
    "$REAL_SMARTCTL" -n standby -i "$DISK" >/dev/null 2>&1
    if [ $? -eq 2 ]; then
        IS_STANDBY=1
    fi
fi

mkdir -p "$CACHE_DIR"
CMD_HASH=$(echo "$*" | md5sum | awk '{print $1}')
CACHE_FILE="$CACHE_DIR/${DEV_NAME}_${CMD_HASH}"
FALLBACK_CACHE="$CACHE_DIR/${DEV_NAME}_fallback"

# WENN DIE PLATTE SCHLÄFT: Niemals die reale Hardware ansprechen!
if [ $IS_STANDBY -eq 1 ]; then
    if [ -f "$CACHE_FILE" ]; then
        cat "$CACHE_FILE"
        exit 0
    elif [ -f "$FALLBACK_CACHE" ]; then
        # Cache-Miss abfangen: Universellen Fallback-Cache liefern
        cat "$FALLBACK_CACHE"
        exit 0
    else
        # Notfall-Fallback, falls noch gar kein Cache existiert
        exit 0
    fi
fi

# Platte ist bereits aktiv: Realen Befehl ausführen
OUTPUT=$("$REAL_SMARTCTL" "$@")
EXIT_CODE=$?

# Bei erfolgreichem Durchlauf Caches befüllen
if [ $EXIT_CODE -eq 0 ]; then
    echo "$OUTPUT" > "$CACHE_FILE"
    echo "$OUTPUT" > "$FALLBACK_CACHE"
fi

echo "$OUTPUT"
exit $EXIT_CODE
