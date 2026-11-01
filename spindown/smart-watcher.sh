#!/bin/bash
CACHE_DIR="/dev/shm/smartctl_cache"
REAL_SMARTCTL="/root/spindown/smartctl.real"

# Prüfintervall in Sekunden: 600s (10 Minuten)
CHECK_INTERVAL=600

declare -A LAST_STATE

update_disk_cache() {
    local disk="$1"
    local dev=$(basename "$disk")
    mkdir -p "$CACHE_DIR"

    # Universellen Fallback-Cache schreiben
    local out=$("$REAL_SMARTCTL" -x "$disk" 2>/dev/null)
    echo "$out" > "$CACHE_DIR/${dev}_fallback"

    # TrueNAS-Standard-Abfragen hashen und cachen
    for args in "-x" "-a" "-j -x" "-A" "-j -A"; do
        local hash=$(echo "$args $disk" | md5sum | awk '{print $1}')
        "$REAL_SMARTCTL" $args "$disk" > "$CACHE_DIR/${dev}_${hash}" 2>/dev/null
    done
}

while true; do
    for d in /dev/sd[a-z]; do
        [ -e "$d" ] || continue
        dev=$(basename "$d")

        # Nur rotierende HDDs prüfen (SSDs überspringen)
        [ "$(cat /sys/block/$dev/queue/rotational 2>/dev/null)" = "1" ] || continue

        # Status abfragen (weckt Platten nicht auf)
        STATE=$(hdparm -C "$d" 2>/dev/null | grep -i "drive state is:" | awk '{print $NF}')

        if [ -z "$STATE" ] || [ "$STATE" = "unknown" ]; then
            "$REAL_SMARTCTL" -n standby -i "$d" >/dev/null 2>&1
            if [ $? -eq 2 ]; then
                STATE="standby"
            else
                STATE="active/idle"
            fi
        fi

        PREV_STATE="${LAST_STATE[$dev]}"

        # Sobald eine Platte von Standby auf Aktiv wechselt: Cache im Hintergrund neu aufbauen
        if [ "$STATE" = "active/idle" ] && [ "$PREV_STATE" = "standby" ]; then
            update_disk_cache "$d" &
        fi

        LAST_STATE[$dev]="$STATE"
    done

    sleep "$CHECK_INTERVAL"
done
