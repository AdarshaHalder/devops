#!/usr/bin/env bash
# Creates a timestamped dump of the local database:
#
#   backups/<db>_<UTC timestamp>.dump           pg_dump custom format (compressed)
#   backups/<db>_<UTC timestamp>.dump.sha256    checksum, verified by restore.sh
#   backups/<db>_<UTC timestamp>.manifest       row counts + data fingerprints
#
# Usage: ./scripts/backup.sh
# Env:   BACKUP_DIR (default ./backups), BACKUP_KEEP (default 10 newest dumps kept)
set -euo pipefail
source "$(dirname "$0")/lib.sh"

BACKUP_KEEP=${BACKUP_KEEP:-10}

require_db
mkdir -p "$BACKUP_DIR"

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
name="${POSTGRES_DB}_${timestamp}"
dump="$BACKUP_DIR/$name.dump"
partial="$dump.partial"
trap 'rm -f "$partial"' EXIT

log "dumping database '$POSTGRES_DB'"
db_exec pg_dump --format=custom --compress=6 --no-owner --no-privileges \
    -U "$POSTGRES_USER" -d "$POSTGRES_DB" > "$partial"

# A dump is only useful if pg_restore can read its table of contents.
db_exec pg_restore --list < "$partial" > /dev/null || die "dump is not readable by pg_restore"
mv "$partial" "$dump"

(cd "$BACKUP_DIR" && sha256 "$name.dump" > "$name.dump.sha256")

# Captured right after the dump; on an idle local database this matches the
# dump's snapshot exactly. restore.sh compares the restored database to it.
fingerprint "$POSTGRES_DB" > "$BACKUP_DIR/$name.manifest"

# Retention: keep the newest $BACKUP_KEEP dumps and their sidecar files.
ls -1t "$BACKUP_DIR"/*.dump 2>/dev/null | tail -n +"$((BACKUP_KEEP + 1))" | while read -r old; do
    log "pruning ${old##*/}"
    rm -f "$old" "$old.sha256" "${old%.dump}.manifest"
done

log "backup written: $dump ($(du -h "$dump" | cut -f1))"
sed 's/^/    /' "$BACKUP_DIR/$name.manifest" >&2
echo "$dump"
