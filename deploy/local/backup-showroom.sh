#!/usr/bin/env bash
# Consistent, encrypted PostgreSQL + Tryton filestore backup.
# Install as root; use only after configuring backup.env and testing restore.
set -Eeuo pipefail
umask 077

: "${PGHOST:?PGHOST is required}"
: "${PGPORT:?PGPORT is required}"
: "${PGUSER:?PGUSER is required}"
: "${PGDATABASE:?PGDATABASE is required}"
: "${PGPASSFILE:?PGPASSFILE is required}"
: "${TRYTOND_FILESTORE:?TRYTOND_FILESTORE is required}"
: "${BACKUP_DIR:?BACKUP_DIR is required}"
: "${AGE_RECIPIENT:?AGE_RECIPIENT is required}"
TRYTOND_SERVICE="${TRYTOND_SERVICE:-trytond.service}"

for command in pg_dump tar age sha256sum systemctl; do
    command -v "$command" >/dev/null 2>&1 || {
        printf 'Required command not found: %s\n' "$command" >&2
        exit 1
    }
done

[[ -r "$PGPASSFILE" ]] || {
    printf 'PostgreSQL password file is not readable: %s\n' "$PGPASSFILE" >&2
    exit 1
}
[[ -d "$TRYTOND_FILESTORE" ]] || {
    printf 'Tryton filestore directory does not exist: %s\n' "$TRYTOND_FILESTORE" >&2
    exit 1
}

install -d -m 0700 "$BACKUP_DIR"
work_dir="$(mktemp -d "$BACKUP_DIR/.backup-work.XXXXXX")"
service_was_active=false

cleanup() {
    status=$?
    if [[ "$service_was_active" == true ]]; then
        systemctl start "$TRYTOND_SERVICE" || {
            printf 'CRITICAL: failed to restart %s after backup. Inspect systemd immediately.\n' "$TRYTOND_SERVICE" >&2
            status=1
        }
    fi
    rm -rf -- "$work_dir"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if systemctl is-active --quiet "$TRYTOND_SERVICE"; then
    service_was_active=true
fi

# Stop the application before taking both snapshots so no sale, stock,
# attachment or filestore write can race with the backup. Stop any separately
# configured Tryton worker/cron or integration writer before running this job.
if [[ "$service_was_active" == true ]]; then
    systemctl stop "$TRYTOND_SERVICE"
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
database_dump="$work_dir/${PGDATABASE}.dump"
filestore_archive="$work_dir/filestore.tar.gz"
bundle="$work_dir/showroom-backup.tar.gz"
encrypted="$BACKUP_DIR/${PGDATABASE}-${timestamp}.tar.gz.age"

export PGPASSFILE
pg_dump \
    --host="$PGHOST" \
    --port="$PGPORT" \
    --username="$PGUSER" \
    --dbname="$PGDATABASE" \
    --format=custom \
    --no-owner \
    --file="$database_dump"

tar -czf "$filestore_archive" -C "$TRYTOND_FILESTORE" .
tar -czf "$bundle" -C "$work_dir" "${PGDATABASE}.dump" filestore.tar.gz
age --recipient "$AGE_RECIPIENT" --output "$encrypted" "$bundle"
sha256sum "$encrypted" > "${encrypted}.sha256"
chmod 0600 "$encrypted" "${encrypted}.sha256"

printf 'Encrypted backup created: %s\n' "$encrypted"
printf 'Checksum: %s\n' "${encrypted}.sha256"
