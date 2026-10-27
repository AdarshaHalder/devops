-- Row count plus an md5 over every column of every row, in primary-key order.
-- Two databases with identical fingerprints hold identical data.
SELECT 'hotel_bookings', count(*), md5(coalesce(string_agg(t::text, E'\n' ORDER BY t.id), ''))
FROM hotel_bookings AS t
UNION ALL
SELECT 'booking_events', count(*), md5(coalesce(string_agg(t::text, E'\n' ORDER BY t.id), ''))
FROM booking_events AS t
UNION ALL
SELECT 'schema_migrations', count(*), md5(coalesce(string_agg(t.version, E'\n' ORDER BY t.version), ''))
FROM schema_migrations AS t;
