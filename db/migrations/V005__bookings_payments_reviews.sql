SET search_path = application, public;

CREATE TYPE booking_status AS ENUM ('created', 'payment_pending', 'confirmed', 'expired', 'cancelled', 'completed');
CREATE TYPE payment_status AS ENUM ('initiated', 'paid', 'failed', 'cancelled', 'expired', 'partially_refunded', 'refunded');

CREATE TABLE bookings
(
    id                       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    listing_id               BIGINT         NOT NULL REFERENCES listings (id),
    created_by_user_id       BIGINT         NOT NULL REFERENCES users (id),
    guests_count             INT            NOT NULL,
    total_amount_currency_id BIGINT         NOT NULL REFERENCES currencies (id),
    total_amount_in_minor    BIGINT         NOT NULL,
    status                   booking_status NOT NULL,
    cancelled_by_user_id     BIGINT REFERENCES users (id),
    cancellation_reason      VARCHAR(512),
    creation_date            TIMESTAMPTZ    NOT NULL DEFAULT now(),
    last_update_date         TIMESTAMPTZ    NOT NULL DEFAULT now(),
    booking_expires_at       TIMESTAMPTZ    NOT NULL,
    CONSTRAINT chk_bookings_expires_after_create CHECK (
        booking_expires_at > creation_date AND
        booking_expires_at <= creation_date + INTERVAL '5 minutes'
    ),
    CONSTRAINT chk_bookings_guests_count_positive CHECK (guests_count > 0),
    CONSTRAINT chk_bookings_total_amount_positive CHECK (total_amount_in_minor > 0),
    CONSTRAINT chk_bookings_update_not_before_create CHECK (last_update_date >= creation_date),
    CONSTRAINT chk_bookings_cancel_reason_required CHECK (
        (status = 'cancelled' AND cancellation_reason IS NOT NULL AND btrim(cancellation_reason) <> '') OR
        (status <> 'cancelled' AND cancellation_reason IS NULL)
    ),
    CONSTRAINT uq_bookings_id_listing_id UNIQUE (id, listing_id)
);

CREATE TABLE booking_days
(
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id          BIGINT      NOT NULL,
    availability_day_id BIGINT      NOT NULL,
    listing_id          BIGINT      NOT NULL,
    creation_date       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_booking_days_booking_day UNIQUE (booking_id, availability_day_id),
    CONSTRAINT fk_booking_days_booking_listing
        FOREIGN KEY (booking_id, listing_id)
        REFERENCES bookings (id, listing_id),
    CONSTRAINT fk_booking_days_listing_day
        FOREIGN KEY (listing_id, availability_day_id)
        REFERENCES listing_availability_days (listing_id, id)
);

CREATE TABLE payments
(
    id                                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id                          BIGINT UNIQUE       NOT NULL REFERENCES bookings (id),
    currency_id                         BIGINT              NOT NULL REFERENCES currencies (id),
    amount_in_minor                     BIGINT              NOT NULL,
    refunded_amount_in_minor            BIGINT              NOT NULL DEFAULT 0,
    status                              payment_status      NOT NULL,
    initiated_date                      TIMESTAMPTZ         NOT NULL DEFAULT now(),
    provider_payment_session_id         VARCHAR(512) UNIQUE NOT NULL,
    provider_payment_session_expires_at TIMESTAMPTZ         NOT NULL,
    last_update_date                    TIMESTAMPTZ         NOT NULL DEFAULT now(),
    CONSTRAINT chk_payments_amount_positive CHECK (amount_in_minor > 0),
    CONSTRAINT chk_payments_refunded_amount_range CHECK (refunded_amount_in_minor >= 0 AND refunded_amount_in_minor <= amount_in_minor),
    CONSTRAINT chk_payments_update_not_before_initiated CHECK (last_update_date >= initiated_date),
    CONSTRAINT chk_payments_session_expires_after_initiated CHECK (provider_payment_session_expires_at > initiated_date)
);

CREATE TABLE reviews
(
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id      BIGINT UNIQUE NOT NULL REFERENCES bookings (id),
    mark            SMALLINT      NOT NULL,
    body            VARCHAR(2048),
    moderated       BOOLEAN       NOT NULL DEFAULT false,
    creation_date   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    moderation_date TIMESTAMPTZ,
    CONSTRAINT chk_reviews_mark_range CHECK (mark BETWEEN 1 AND 5),
    CONSTRAINT chk_reviews_body_not_blank CHECK (body IS NULL OR btrim(body) <> ''),
    CONSTRAINT chk_reviews_moderation_consistency CHECK (
        (moderated = false AND moderation_date IS NULL) OR
        (moderated = true AND moderation_date IS NOT NULL AND moderation_date >= creation_date)
    )
);

CREATE OR REPLACE FUNCTION trg_bookings_validate_status_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = application, public, pg_temp
AS
$$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status
       AND OLD.status = 'payment_pending'
       AND NEW.status = 'cancelled' THEN
        RAISE EXCEPTION 'booking_id=% cannot be cancelled while status is payment_pending', OLD.id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_bookings_validate_status_transition
    BEFORE UPDATE ON bookings
    FOR EACH ROW
EXECUTE FUNCTION trg_bookings_validate_status_transition();

CREATE OR REPLACE FUNCTION trg_booking_days_prevent_active_overlap()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = application, public, pg_temp
AS
$$
DECLARE
    v_booking_status booking_status;
    v_listing_status listing_publication_status;
    v_conflict BOOLEAN;
BEGIN
    SELECT status INTO v_booking_status FROM bookings WHERE id = NEW.booking_id FOR UPDATE;
    IF v_booking_status NOT IN ('created', 'payment_pending', 'confirmed') THEN
        RAISE EXCEPTION 'booking_id=% has non-active status=%', NEW.booking_id, v_booking_status;
    END IF;

    SELECT status INTO v_listing_status FROM listings WHERE id = NEW.listing_id FOR UPDATE;
    IF v_listing_status IS DISTINCT FROM 'active' THEN
        RAISE EXCEPTION 'listing_id=% must be active for booking day assignment', NEW.listing_id;
    END IF;

    PERFORM 1 FROM listing_availability_days
    WHERE id = NEW.availability_day_id AND listing_id = NEW.listing_id
    FOR UPDATE;

    SELECT EXISTS (
        SELECT 1
        FROM booking_days bd
                 JOIN bookings b ON b.id = bd.booking_id
        WHERE bd.availability_day_id = NEW.availability_day_id
          AND bd.listing_id = NEW.listing_id
          AND bd.booking_id <> NEW.booking_id
          AND b.status IN ('created', 'payment_pending', 'confirmed')
    ) INTO v_conflict;

    IF v_conflict THEN
        RAISE EXCEPTION 'availability_day_id=% is already linked to another active booking', NEW.availability_day_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_booking_days_prevent_active_overlap
    BEFORE INSERT OR UPDATE ON booking_days
    FOR EACH ROW
EXECUTE FUNCTION trg_booking_days_prevent_active_overlap();

CREATE OR REPLACE FUNCTION trg_payments_require_not_expired_booking()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = application, public, pg_temp
AS
$$
DECLARE
    v_booking_expires_at TIMESTAMPTZ;
BEGIN
    SELECT booking_expires_at INTO v_booking_expires_at
    FROM bookings
    WHERE id = NEW.booking_id
    FOR UPDATE;

    IF now() > v_booking_expires_at THEN
        RAISE EXCEPTION 'payment session cannot start after booking expiration, booking_id=%', NEW.booking_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_payments_require_not_expired_booking
    BEFORE INSERT ON payments
    FOR EACH ROW
EXECUTE FUNCTION trg_payments_require_not_expired_booking();

CREATE OR REPLACE FUNCTION trg_reviews_require_completed_booking()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = application, public, pg_temp
AS
$$
DECLARE
    v_booking_status booking_status;
BEGIN
    SELECT status INTO v_booking_status FROM bookings WHERE id = NEW.booking_id FOR UPDATE;
    IF v_booking_status <> 'completed' THEN
        RAISE EXCEPTION 'review is allowed only for completed booking, booking_id=% has status=%', NEW.booking_id, v_booking_status;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_reviews_require_completed_booking
    BEFORE INSERT OR UPDATE ON reviews
    FOR EACH ROW
EXECUTE FUNCTION trg_reviews_require_completed_booking();
