CREATE TABLE hotel_bookings (
    id            UUID           PRIMARY KEY,
    org_id        UUID           NOT NULL,
    hotel_id      VARCHAR(100)   NOT NULL,
    city          VARCHAR(100)   NOT NULL,
    checkin_date  DATE           NOT NULL,
    checkout_date DATE           NOT NULL,
    amount        NUMERIC(12, 2) NOT NULL,
    status        VARCHAR(50)    NOT NULL,
    created_at    TIMESTAMP      NOT NULL DEFAULT now(),

    CONSTRAINT hotel_bookings_dates_chk  CHECK (checkout_date > checkin_date),
    CONSTRAINT hotel_bookings_amount_chk CHECK (amount >= 0),
    -- Cities are stored normalised so `city = 'delhi'` is an exact, indexable match.
    CONSTRAINT hotel_bookings_city_chk   CHECK (city = lower(btrim(city))),
    CONSTRAINT hotel_bookings_status_chk CHECK (
        status IN ('pending', 'confirmed', 'cancelled', 'completed', 'refunded')
    )
);
