#!/usr/bin/env bash

# Basis-Verzeichnis für alle Docker-Anwendungen
BASE_DIR="/mnt/FastPool/Apps/Docker"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starte Docker Pull-Prozess..."

# Findet alle direkten Unterverzeichnisse
find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d | sort | while read -r dir; do
    APP_NAME=$(basename "$dir")

    # Prüfen, ob automatische Updates deaktiviert sind
    if [[ -f "$dir/.update_disable" || -f "$dir/update_disable" ]]; then
        echo "[SKIP] Automatischer Pull deaktiviert für: $APP_NAME"
        continue
    fi

    # Prüfen, ob eine Compose-Datei existiert
    if [[ ! -f "$dir/docker-compose.yml" && ! -f "$dir/docker-compose.yaml" && ! -f "$dir/compose.yml" ]]; then
        echo "[WARN] Keine Compose-Datei gefunden in: $APP_NAME"
        continue
    fi

    echo "[INFO] Lade Images für: $APP_NAME"
    cd "$dir" || continue
    docker compose pull
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pull-Prozess abgeschlossen."
