#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT_DIR="$(cd "$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/deploy/docker/.env"
COMPOSE_FILE="$ROOT_DIR/deploy/docker/compose.yml"
BACKUP_DIR="\${BACKUP_DIR:-$ROOT_DIR/backups}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTPUT_DIR="$BACKUP_DIR/$STAMP"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Missing $ENV_FILE. Copy .env.example to .env and configure it." >&2
    exit 1
fi

dc() {
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

RUNNING_SERVICES="$(dc ps --services --status running)"
WAS_SERVER_RUNNING=0
WAS_CRON_RUNNING=0
grep -qx "server" <<<"$RUNNING_SERVICES" && WAS_SERVER_RUNNING=1 || true
grep -qx "cron" <<<"$RUNNING_SERVICES" && WAS_CRON_RUNNING=1 || true
grep -qx "postgres" <<<"$RUNNING_SERVICES" || {
    echo "PostgreSQL must be running. Start ALIF Retail before creating a backup." >&2
    exit 1
}

mkdir -p "$OUTPUT_DIR"
chmod 700 "$BACKUP_DIR" "$OUTPUT_DIR"

restart_previous_services() {
    if (( WAS_SERVER_RUNNING )); then
        dc start server >/dev/null
    fi
    if (( WAS_CRON_RUNNING )); then
        dc start cron >/dev/null
    fi
}

# Stop application writes so the database dump and filestore archive form
# one consistent maintenance-window backup. Preserve the prior run state.
dc stop cron server
trap restart_previous_services EXIT

dc run --rm --no-deps --volume "$OUTPUT_DIR:/backup" --entrypoint sh postgres -c \
    'set -eu; export PGPASSWORD="$POSTGRES_PASSWORD"; pg_dump -h postgres -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-password --format=custom --no-owner --no-acl --file=/backup/database.dump'

dc run --rm --no-deps --volume "$OUTPUT_DIR:/backup" --entrypoint sh server -c \
    'set -eu; tar -C /var/lib/trytond -czf /backup/filestore.tar.gz db'

(
    cd "$OUTPUT_DIR"
    sha256sum database.dump filestore.tar.gz > SHA256SUMS
)

restart_previous_services
trap - EXIT

echo "Backup complete: $OUTPUT_DIR"
echo "Copy the complete timestamped folder to encrypted storage separate from this PC."
