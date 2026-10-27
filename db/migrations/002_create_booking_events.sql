CREATE TABLE booking_events (
    id         BIGSERIAL    PRIMARY KEY,
    booking_id UUID         NOT NULL REFERENCES hotel_bookings (id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    payload    JSONB,
    created_at TIMESTAMP    NOT NULL DEFAULT now()
);

-- Postgres does not index foreign keys automatically. This serves both the
-- "timeline of a booking" lookup and the cascade from hotel_bookings.
CREATE INDEX booking_events_booking_id_created_at_idx
    ON booking_events (booking_id, created_at);
