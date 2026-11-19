#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/deploy/docker/.env"
COMPOSE_FILE="$ROOT_DIR/deploy/docker/compose.yml"
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Missing $ENV_FILE. Copy .env.example to .env and configure it." >&2
    exit 1
fi

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

dc() {
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

restart_services() {
    dc start server cron >/dev/null 2>&1 || true
}

# Stop application writes so the database dump and filestore archive form
# one consistent maintenance-window backup.
dc stop cron server
trap restart_services EXIT

dc run --rm --no-deps --entrypoint sh postgres -c \
    'pg_dump -h postgres -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
    > "$BACKUP_DIR/database-$STAMP.dump"

dc run --rm --no-deps --entrypoint sh server -c \
    'tar -C /var/lib/trytond -czf - db' \
    > "$BACKUP_DIR/filestore-$STAMP.tar.gz"

sha256sum "$BACKUP_DIR/database-$STAMP.dump" \
    "$BACKUP_DIR/filestore-$STAMP.tar.gz" \
    > "$BACKUP_DIR/SHA256SUMS-$STAMP"

restart_services
trap - EXIT

echo "Backup complete: $BACKUP_DIR ($STAMP)"
