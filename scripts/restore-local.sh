#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT_DIR="$(cd "$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/deploy/docker/.env"
COMPOSE_FILE="$ROOT_DIR/deploy/docker/compose.yml"

usage() {
    echo "Usage: $0 <timestamped-backup-directory>" >&2
    exit 2
}

[[ $# -eq 1 ]] || usage
BACKUP_DIR="$(cd "$1" && pwd)"

for file in database.dump filestore.tar.gz SHA256SUMS; do
    [[ -f "$BACKUP_DIR/$file" ]] || {
        echo "Missing backup file: $BACKUP_DIR/$file" >&2
        exit 1
    }
done
[[ -f "$ENV_FILE" ]] || {
    echo "Missing $ENV_FILE. Configure the same deployment before restoring." >&2
    exit 1
}

(
    cd "$BACKUP_DIR"
    sha256sum --check --strict SHA256SUMS
)

echo "WARNING: this permanently replaces the current ALIF Retail database and filestore."
read -r -p 'Type RESTORE to continue: ' confirmation
[[ "$confirmation" == "RESTORE" ]] || {
    echo "Restore cancelled."
    exit 1
}

dc() {
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

dc up -d postgres
deadline=$((SECONDS + 180))
until dc exec -T postgres sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then
        echo "PostgreSQL did not become ready; restore was not started." >&2
        exit 1
    fi
    sleep 3
done

# Keep the application stopped if either half of the restore fails.
dc stop server cron

dc run --rm --no-deps --volume "$BACKUP_DIR:/restore:ro" --entrypoint sh postgres -c \
    'set -eu; export PGPASSWORD="$POSTGRES_PASSWORD"; dropdb -h postgres -U "$POSTGRES_USER" --maintenance-db=postgres --if-exists "$POSTGRES_DB"; createdb -h postgres -U "$POSTGRES_USER" --maintenance-db=postgres --owner="$POSTGRES_USER" "$POSTGRES_DB"; pg_restore --exit-on-error --no-owner --role="$POSTGRES_USER" -h postgres -U "$POSTGRES_USER" -d "$POSTGRES_DB" /restore/database.dump'

dc run --rm --no-deps --volume "$BACKUP_DIR:/restore:ro" --entrypoint sh server -c \
    'set -eu; mkdir -p /var/lib/trytond/db; find /var/lib/trytond/db -mindepth 1 -maxdepth 1 -exec rm -rf {} +; tar -C /var/lib/trytond -xzf /restore/filestore.tar.gz'

dc up -d server cron
dc ps

echo "Database and filestore restored. Validate login, attachments, stock, balances and a test invoice before returning to trading."
