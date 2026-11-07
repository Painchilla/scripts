#!/bin/bash
CACHE_DIR="/dev/shm/smartctl_cache"
REAL_SMARTCTL="/root/spindown/smartctl.real"

# Prüfintervall: 60 Sekunden (durch RAM-Abfrage völlig CPU-neutral)
CHECK_INTERVAL=60
# Cooldown in Sekunden
COOLDOWN=5400

declare -A LAST_IO
declare -A LAST_UPDATE

update_disk_cache() {
    local disk="$1"
    local dev="${disk##*/}"
    mkdir -p "$CACHE_DIR"

    # Basis-Fallback anlegen
    "$REAL_SMARTCTL" -x "$disk" > "$CACHE_DIR/${dev}_fallback" 2>/dev/null

    # Standardabfragen ohne awk/grep hashen und ablegen
    for args in "-x" "-a" "-j -x" "-A" "-j -A"; do
        local h=$(echo "$args $disk" | md5sum)
        h="${h%% *}"
        "$REAL_SMARTCTL" $args "$disk" > "$CACHE_DIR/${dev}_${h}" 2>/dev/null
    done
}

while true; do
    current_time=$(date +%s)

    for d in /dev/sd[a-z]; do
        [ -e "$d" ] || continue
        dev="${d##*/}"

        # Nur mechanische HDDs prüfen (ohne cat-Subshell)
        [ -f "/sys/block/$dev/queue/rotational" ] || continue
        read -r is_rotational < "/sys/block/$dev/queue/rotational"
        [ "$is_rotational" = "1" ] || continue

        # I/O-Statistik direkt per Kernel-RAM auslesen (0 Forks, 0 % CPU)
        stat_file="/sys/block/$dev/stat"
        [ -f "$stat_file" ] || continue
        read -r r_ios _ _ _ w_ios _ < "$stat_file"
        total_io=$(( r_ios + w_ios ))

        prev_io="${LAST_IO[$dev]}"
        last_up="${LAST_UPDATE[$dev]:-0}"

        # Wenn I/O stattfand und der Cooldown abgelaufen ist:
        if [ -n "$prev_io" ] && [ "$total_io" -gt "$prev_io" ]; then
            if [ $(( current_time - last_up )) -gt "$COOLDOWN" ]; then
                # Nur im Bedarfsfall kurz prüfen, ob die Platte tatsächlich hochgedreht hat
                state=$(hdparm -C "$d" 2>/dev/null)
                if [[ "$state" =~ "active" ]]; then
                    update_disk_cache "$d" &
                    LAST_UPDATE[$dev]="$current_time"
                fi
            fi
        fi

        LAST_IO[$dev]="$total_io"
    done

    sleep "$CHECK_INTERVAL"
done
