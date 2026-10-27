#!/usr/bin/env bash
# Restores a dump into a brand-new database and proves the restore is complete.
#
# Usage: ./scripts/restore.sh [DUMP_FILE] [TARGET_DB]
#   DUMP_FILE  default: newest backups/*.dump
#   TARGET_DB  default: <POSTGRES_DB>_restored  (dropped and recreated each run)
#
# Steps: verify checksum -> recreate target DB -> pg_restore in one transaction
#        -> compare row counts and data fingerprints with the backup manifest.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

dump=${1:-$(ls -1t "$BACKUP_DIR"/*.dump 2>/dev/null | head -n 1 || true)}
target=${2:-${POSTGRES_DB}_restored}

[[ -n "$dump" ]] || die "no dump found in $BACKUP_DIR; run ./scripts/backup.sh first"
[[ -f "$dump" ]] || die "dump file not found: $dump"
[[ "$target" =~ ^[a-z_][a-z0-9_]*$ ]] || die "invalid target database name: $target"
[[ "$target" != "$POSTGRES_DB" ]] || die "refusing to overwrite the live database '$POSTGRES_DB'; pick another target"

dump_dir=$(cd "$(dirname "$dump")" && pwd)
dump_name=$(basename "$dump")
manifest="$dump_dir/${dump_name%.dump}.manifest"

require_db

if [[ -f "$dump_dir/$dump_name.sha256" ]]; then
    (cd "$dump_dir" && sha256 -c --status "$dump_name.sha256") || die "checksum mismatch for $dump_name"
    log "checksum OK"
else
    log "WARNING: no .sha256 next to $dump_name, skipping checksum check"
fi

log "recreating database '$target'"
db_psql -d postgres -c "DROP DATABASE IF EXISTS \"$target\" WITH (FORCE)"
db_psql -d postgres -c "CREATE DATABASE \"$target\""

log "restoring $dump_name into '$target'"
db_exec pg_restore --exit-on-error --single-transaction --no-owner --no-privileges \
    -U "$POSTGRES_USER" -d "$target" < "$dump"

log "verifying restored data"
actual=$(fingerprint "$target")

if [[ -f "$manifest" ]]; then
    if diff "$manifest" <(echo "$actual") > /dev/null; then
        log "row counts and fingerprints match the backup manifest:"
        echo "$actual" | sed 's/^/    /' >&2
    else
        log "expected (manifest) vs actual (restored):"
        diff "$manifest" <(echo "$actual") >&2 || true
        die "restored data does not match the backup"
    fi
else
    log "WARNING: no manifest for $dump_name, showing restored counts only:"
    echo "$actual" | sed 's/^/    /' >&2
fi

index_count=$(db_psql -d "$target" -tA -c \
    "SELECT count(*) FROM pg_indexes WHERE tablename IN ('hotel_bookings', 'booking_events')")
log "indexes restored on application tables: $index_count"
log "restore OK -> connect with: docker compose exec db psql -U $POSTGRES_USER -d $target"
