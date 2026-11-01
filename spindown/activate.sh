#!/bin/bash
mkdir -p /root/spindown /dev/shm/smartctl_cache

if [ ! -f /root/spindown/smartctl.real ]; then
    cp /usr/sbin/smartctl /root/spindown/smartctl.real
    chmod +x /root/spindown/smartctl.real
fi

if ! mountpoint -q /usr/sbin/smartctl; then
    mount --bind /root/spindown/smartctl-wrapper.sh /usr/sbin/smartctl
fi

# Initialen Cache parallel beim Start befüllen (während die Platten vom Booten noch drehen)
(
    for d in /dev/sd[a-z]; do
        dev=$(basename "$d")
        if [ -e "$d" ] && [ "$(cat /sys/block/$dev/queue/rotational 2>/dev/null)" = "1" ]; then
            (
                out=$(/root/spindown/smartctl.real -x "$d" 2>/dev/null)
                echo "$out" > "/dev/shm/smartctl_cache/${dev}_fallback"
                for args in "-x" "-a" "-j -x" "-A" "-j -A"; do
                    h=$(echo "$args $d" | md5sum | awk '{print $1}')
                    /root/spindown/smartctl.real $args "$d" > "/dev/shm/smartctl_cache/${dev}_${h}" 2>/dev/null
                done
            ) &
        fi
    done
    wait
) >/dev/null 2>&1 &

# Alten Watcher beenden (falls vorhanden) und neu im Hintergrund starten
pkill -f /root/spindown/smart-watcher.sh 2>/dev/null
/root/spindown/smart-watcher.sh >/dev/null 2>&1 &

exit 0
