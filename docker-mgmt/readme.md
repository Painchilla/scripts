# Docker MGMT Scripts

Sammlung von Bash-Skripten zur automatisierten Wartung lokaler Docker-Container via Cron.

## Funktion

*   **`pull_images.sh`**: Iteriert durch alle Ordner unter `/mnt/FastPool/Apps/Docker` und führt `docker compose pull` aus.
*   **`update_containers.sh`**: Startet Container mit neuen Images neu (`docker compose up -d --remove-orphans`).

## Updates für einzelne Container deaktivieren

Um den automatischen Pull und Update-Prozess für ein bestimmtes Verzeichnis zu verhindern, muss eine leere Datei namens `.update_disable` im jeweiligen App-Verzeichnis angelegt werden:

```bash
touch /mnt/FastPool/Apps/Docker/MeineApp/.update_disable

