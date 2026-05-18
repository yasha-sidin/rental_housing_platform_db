SET search_path = application, public;

CREATE TABLE base_prices
(
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    currency_id      BIGINT        NOT NULL REFERENCES currencies (id),
    amount_in_minor  BIGINT        NOT NULL,
    listing_id       BIGINT UNIQUE NOT NULL REFERENCES listings (id),
    creation_date    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    last_update_date TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT chk_base_prices_amount_positive CHECK (amount_in_minor > 0),
    CONSTRAINT chk_base_prices_update_not_before_create CHECK (last_update_date >= creation_date)
);

CREATE TABLE listing_availability_days
(
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    available_date       DATE                NOT NULL,
    status               availability_status NOT NULL,
    listing_id           BIGINT              NOT NULL REFERENCES listings (id),
    creation_date        TIMESTAMPTZ         NOT NULL DEFAULT now(),
    last_update_date     TIMESTAMPTZ         NOT NULL DEFAULT now(),
    override_currency_id BIGINT REFERENCES currencies (id),
    override_in_minor    BIGINT,
    CONSTRAINT uq_listing_availability_days_listing_id_id UNIQUE (listing_id, id),
    UNIQUE (listing_id, available_date),
    CONSTRAINT chk_listing_availability_days_update_not_before_create CHECK (last_update_date >= creation_date),
    CONSTRAINT chk_listing_availability_days_override_pair CHECK (
        (override_currency_id IS NULL AND override_in_minor IS NULL) OR
        (override_currency_id IS NOT NULL AND override_in_minor IS NOT NULL AND override_in_minor > 0)
    )
);

CREATE TABLE price_history
(
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    listing_id          BIGINT              NOT NULL REFERENCES listings (id),
    source              price_change_source NOT NULL,
    availability_day_id BIGINT REFERENCES listing_availability_days (id),
    old_currency_id     BIGINT REFERENCES currencies (id),
    new_currency_id     BIGINT REFERENCES currencies (id),
    old_amount_in_minor BIGINT,
    new_amount_in_minor BIGINT,
    changed_at          TIMESTAMPTZ         NOT NULL DEFAULT now(),
    changed_by_user_id  BIGINT REFERENCES users (id),
    reason              VARCHAR(512),
    CONSTRAINT chk_price_history_source_link CHECK (
        (source = 'base_price' AND availability_day_id IS NULL) OR
        (source = 'day_override' AND availability_day_id IS NOT NULL)
    ),
    CONSTRAINT chk_price_history_amount_change_present CHECK (old_amount_in_minor IS NOT NULL OR new_amount_in_minor IS NOT NULL),
    CONSTRAINT chk_price_history_currency_change_present CHECK (old_currency_id IS NOT NULL OR new_currency_id IS NOT NULL),
    CONSTRAINT fk_price_history_listing_day
        FOREIGN KEY (listing_id, availability_day_id)
        REFERENCES listing_availability_days (listing_id, id)
);

CREATE OR REPLACE FUNCTION trg_base_prices_write_history()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = application, public, pg_temp
AS
$$
BEGIN
    IF OLD.amount_in_minor IS DISTINCT FROM NEW.amount_in_minor
       OR OLD.currency_id IS DISTINCT FROM NEW.currency_id THEN
        INSERT INTO price_history (listing_id, source, old_currency_id, new_currency_id,
                                   old_amount_in_minor, new_amount_in_minor, reason)
        VALUES (NEW.listing_id, 'base_price', OLD.currency_id, NEW.currency_id,
                OLD.amount_in_minor, NEW.amount_in_minor, 'base price updated');
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_base_prices_write_history
    AFTER UPDATE ON base_prices
    FOR EACH ROW
EXECUTE FUNCTION trg_base_prices_write_history();

CREATE OR REPLACE FUNCTION trg_listing_availability_days_write_history()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = application, public, pg_temp
AS
$$
BEGIN
    IF OLD.override_in_minor IS DISTINCT FROM NEW.override_in_minor
       OR OLD.override_currency_id IS DISTINCT FROM NEW.override_currency_id THEN
        INSERT INTO price_history (listing_id, source, availability_day_id, old_currency_id, new_currency_id,
                                   old_amount_in_minor, new_amount_in_minor, reason)
        VALUES (NEW.listing_id, 'day_override', NEW.id, OLD.override_currency_id, NEW.override_currency_id,
                OLD.override_in_minor, NEW.override_in_minor, 'day override updated');
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_listing_availability_days_write_history
    AFTER UPDATE ON listing_availability_days
    FOR EACH ROW
EXECUTE FUNCTION trg_listing_availability_days_write_history();

CREATE OR REPLACE FUNCTION trg_listing_availability_days_prevent_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN
    RAISE EXCEPTION 'physical delete is forbidden for listing_availability_days (day_id=%). Use status update instead.', OLD.id;
END;
$$;

CREATE TRIGGER trg_listing_availability_days_prevent_delete
    BEFORE DELETE ON listing_availability_days
    FOR EACH ROW
EXECUTE FUNCTION trg_listing_availability_days_prevent_delete();
