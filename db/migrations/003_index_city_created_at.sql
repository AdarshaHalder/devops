-- Supports the per-city 30-day rollup:
--
--   SELECT org_id, status, COUNT(*), SUM(amount)
--   FROM hotel_bookings
--   WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
--   GROUP BY org_id, status;
--
-- Equality column first, range column second, so the scan is one contiguous
-- slice of the index. INCLUDE carries the grouped/aggregated columns in the
-- leaf pages, which allows an Index Only Scan with no heap lookups.
-- See README.md, "Query optimisation", for the reasoning.
--
-- On a live production table, run this as CREATE INDEX CONCURRENTLY (outside
-- a transaction) to avoid blocking writes.
CREATE INDEX hotel_bookings_city_created_at_idx
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
