#!/usr/bin/env bash

BASE_DIR="/mnt/FastPool/Apps/Docker"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starte Docker Update-Prozess..."

find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d | sort | while read -r dir; do
    APP_NAME=$(basename "$dir")

    if [[ -f "$dir/.update_disable" || -f "$dir/update_disable" ]]; then
        echo "[SKIP] Automatisches Update deaktiviert für: $APP_NAME"
        continue
    fi

    if [[ ! -f "$dir/docker-compose.yml" && ! -f "$dir/docker-compose.yaml" && ! -f "$dir/compose.yml" ]]; then
        continue
    fi

    echo "[INFO] Aktualisiere Container für: $APP_NAME"
    cd "$dir" || continue
    
    # Startet Container neu, falls ein neues Image vorliegt oder sich die Config geändert hat
    docker compose up -d --remove-orphans
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Update-Prozess abgeschlossen."
