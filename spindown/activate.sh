#!/bin/bash
mkdir -p /root/spindown /dev/shm/smartctl_cache

# 1. Originales smartctl sichern (falls noch nicht geschehen)
if [ ! -f /root/spindown/smartctl.real ]; then
    cp /usr/sbin/smartctl /root/spindown/smartctl.real
    chmod +x /root/spindown/smartctl.real
fi

# 2. Wrapper per Bind-Mount aktivieren
if ! mountpoint -q /usr/sbin/smartctl; then
    mount --bind /root/spindown/smartctl-wrapper.sh /usr/sbin/smartctl
fi

# 3. Cache beim Start parallel vorwärmen (Platten drehen nach Boot ohnehin)
(
    for d in /dev/sd[a-z]; do
        [ -e "$d" ] || continue
        dev="${d##*/}"
        
        [ -f "/sys/block/$dev/queue/rotational" ] || continue
        read -r is_rot < "/sys/block/$dev/queue/rotational"
        [ "$is_rot" = "1" ] || continue

        (
            out=$(/root/spindown/smartctl.real -x "$d" 2>/dev/null)
            echo "$out" > "/dev/shm/smartctl_cache/${dev}_fallback"
            for args in "-x" "-a" "-j -x" "-A" "-j -A"; do
                h=$(echo "$args $d" | md5sum)
                h="${h%% *}"
                /root/spindown/smartctl.real $args "$d" > "/dev/shm/smartctl_cache/${dev}_${h}" 2>/dev/null
            done
        ) &
    done
    wait
) >/dev/null 2>&1 &

# 4. Alte Watcher-Instanzen sicher terminieren und neu starten
pkill -9 -f /root/spindown/smart-watcher.sh 2>/dev/null
/root/spindown/smart-watcher.sh >/dev/null 2>&1 &

exit 0
