#!/bin/sh
# Applies db/migrations/*.sql in order (each in its own transaction, tracked in
# schema_migrations), then runs db/seed/seed.sql. Runs inside the `migrate`
# compose service; connection settings come from the standard PG* variables.
set -eu

MIGRATIONS_DIR=${MIGRATIONS_DIR:-/db/migrations}
SEED_FILE=${SEED_FILE:-/db/seed/seed.sql}
export PGOPTIONS="${PGOPTIONS:-} -c client_min_messages=warning"

psql_q() { psql -X -q -v ON_ERROR_STOP=1 "$@"; }

psql_q -c "CREATE TABLE IF NOT EXISTS schema_migrations (
             version    TEXT        PRIMARY KEY,
             applied_at TIMESTAMPTZ NOT NULL DEFAULT now())"

for file in "$MIGRATIONS_DIR"/*.sql; do
    version=$(basename "$file" .sql)
    if [ -n "$(psql_q -tA -c "SELECT 1 FROM schema_migrations WHERE version = '$version'")" ]; then
        echo "migrate: $version already applied"
        continue
    fi
    echo "migrate: applying $version"
    {
        echo "BEGIN;"
        cat "$file"
        echo
        echo "INSERT INTO schema_migrations (version) VALUES ('$version');"
        echo "COMMIT;"
    } | psql_q
done

echo "migrate: seeding (skipped for tables that already have data)"
psql_q -v bookings="${SEED_BOOKINGS:-1000}" -f "$SEED_FILE"

psql_q -tA -F ' ' -c "SELECT 'migrate: hotel_bookings=' || count(*) FROM hotel_bookings
                      UNION ALL
                      SELECT 'migrate: booking_events=' || count(*) FROM booking_events"
