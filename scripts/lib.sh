# Shared helpers for backup.sh / restore.sh. Sourced, not executed.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Same defaults as docker-compose.yml; .env overrides them.
if [[ -f "$REPO_ROOT/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$REPO_ROOT/.env"
    set +a
fi
POSTGRES_USER=${POSTGRES_USER:-app}
POSTGRES_DB=${POSTGRES_DB:-hotel_bookings}
BACKUP_DIR=${BACKUP_DIR:-$REPO_ROOT/backups}
FINGERPRINT_SQL="$REPO_ROOT/scripts/sql/fingerprint.sql"

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

# Runs a command inside the db container. pg_dump/pg_restore/psql therefore
# always match the server version and nothing has to be installed locally.
compose() { docker compose -f "$REPO_ROOT/docker-compose.yml" "$@"; }
db_exec() { compose exec -T db "$@"; }

db_psql() { db_exec psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" "$@"; }

require_db() {
    command -v docker >/dev/null || die "docker is not installed"
    compose ps --status running --services 2>/dev/null | grep -qx db \
        || die "the db service is not running; start it with: docker compose up -d"
    db_exec pg_isready -q -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        || die "postgres is not accepting connections yet"
}

# Prints "<table> <rows> <md5 of all rows>" for each application table.
fingerprint() {
    db_psql -d "$1" -tA -F ' ' < "$FINGERPRINT_SQL"
}

sha256() {
    if command -v sha256sum >/dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi
}
