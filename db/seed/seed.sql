-- Deterministic seed data. Only runs against empty tables, so it is safe to
-- re-run. Row count comes from the psql variable :bookings (default 1000 via
-- SEED_BOOKINGS in docker-compose.yml).
--
-- IDs are derived from md5() and random() is seeded, so every fresh database
-- gets identical data.

SELECT setseed(0.42) \gset

INSERT INTO hotel_bookings (id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
WITH s AS MATERIALIZED (
    -- Every random() is drawn exactly once per row here; the outer SELECT
    -- only combines the results.
    SELECT
        n,
        1 + floor(random() * 6)::int  AS org_no,
        1 + floor(random() * 25)::int AS hotel_no,
        1 + floor(random() * 6)::int  AS nights,
        1 + floor(random() * 60)::int AS lead_days,
        2500 + random() * 9500        AS nightly_rate,
        -- delhi is listed twice so it is the busiest city.
        (ARRAY['delhi', 'delhi', 'mumbai', 'bengaluru', 'chennai',
               'hyderabad', 'kolkata', 'pune', 'goa', 'jaipur'])[1 + floor(random() * 10)::int] AS city,
        (ARRAY['confirmed', 'confirmed', 'confirmed', 'completed', 'completed',
               'pending', 'cancelled', 'refunded'])[1 + floor(random() * 8)::int] AS status,
        -- Spread over 120 days so the 30-day filter excludes most rows.
        date_trunc('second', now()::timestamp - random() * interval '120 days') AS created_at
    FROM generate_series(1, :bookings) AS n
)
SELECT
    md5('booking-' || n)::uuid,
    md5('org-' || org_no)::uuid,
    city || '-hotel-' || lpad(hotel_no::text, 3, '0'),
    city,
    (created_at + lead_days * interval '1 day')::date,
    (created_at + lead_days * interval '1 day')::date + nights,
    round((nights * nightly_rate)::numeric, 2),
    status,
    created_at
FROM s
WHERE NOT EXISTS (SELECT 1 FROM hotel_bookings);

-- Lifecycle events for roughly three quarters of the bookings; the event
-- trail follows the booking's final status.
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT
    b.id,
    f.event_type,
    jsonb_build_object(
        'hotel_id', b.hotel_id,
        'city',     b.city,
        'amount',   b.amount,
        'source',   'seed'
    ),
    b.created_at + f.step * interval '3 hours'
FROM hotel_bookings AS b
JOIN (VALUES
    ('pending',   'booking_created',   0),
    ('confirmed', 'booking_created',   0),
    ('confirmed', 'payment_captured',  1),
    ('confirmed', 'booking_confirmed', 2),
    ('completed', 'booking_created',   0),
    ('completed', 'payment_captured',  1),
    ('completed', 'booking_confirmed', 2),
    ('completed', 'checked_in',        3),
    ('completed', 'checked_out',       4),
    ('cancelled', 'booking_created',   0),
    ('cancelled', 'booking_cancelled', 1),
    ('refunded',  'booking_created',   0),
    ('refunded',  'payment_captured',  1),
    ('refunded',  'booking_cancelled', 2),
    ('refunded',  'refund_issued',     3)
) AS f (status, event_type, step) ON f.status = b.status
WHERE (hashtext(b.id::text) & 3) <> 0
  AND NOT EXISTS (SELECT 1 FROM booking_events)
ORDER BY b.created_at, b.id, f.step;

-- Fresh statistics and visibility map, so the planner can choose an index-only scan.
VACUUM ANALYZE hotel_bookings;
VACUUM ANALYZE booking_events;
