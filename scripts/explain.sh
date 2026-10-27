#!/usr/bin/env bash
# Shows the execution plan for the reporting query from the assignment.
# Usage: ./scripts/explain.sh [DB_NAME]
set -euo pipefail
source "$(dirname "$0")/lib.sh"

require_db
db_psql -d "${1:-$POSTGRES_DB}" <<'SQL'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
SQL
