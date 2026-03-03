-- V005: ценообразование и календарь доступности по дням.
-- Зависимости: listings (V004), users (V003).

-- Актуальная базовая цена объекта: одна запись на один listing.
CREATE TABLE base_prices
(
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    currency_id      BIGINT        NOT NULL REFERENCES currencies (id),
    -- Храним в minor units (например, центы), чтобы избежать ошибок округления float/decimal.
    amount_in_minor  BIGINT        NOT NULL,
    listing_id       BIGINT UNIQUE NOT NULL REFERENCES listings (id),
    creation_date    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    last_update_date TIMESTAMPTZ   NOT NULL DEFAULT now(),
    -- Проверка исключает нулевую и отрицательную цену.
    CONSTRAINT chk_base_prices_amount_positive
        CHECK (amount_in_minor > 0),
    -- Проверка защищает временную целостность записи.
    CONSTRAINT chk_base_prices_update_not_before_create
        CHECK (last_update_date >= creation_date)
);

-- Дневная доступность: одна дата = одна запись.
CREATE TABLE listing_availability_days
(
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    available_date       DATE                NOT NULL,
    status               availability_status NOT NULL,
    listing_id           BIGINT              NOT NULL REFERENCES listings (id),
    creation_date        TIMESTAMPTZ         NOT NULL DEFAULT now(),
    last_update_date     TIMESTAMPTZ         NOT NULL DEFAULT now(),
    -- Override-цена на конкретный день. Если поля NULL, применяется базовая цена из base_prices.
    override_currency_id BIGINT REFERENCES currencies (id),
    override_in_minor    BIGINT,
    -- Дополнительная уникальность нужна для составного FK из price_history.
    -- Она гарантирует, что пара (listing_id, id) однозначно идентифицирует день.
    CONSTRAINT uq_listing_availability_days_listing_id_id UNIQUE (listing_id, id),
    UNIQUE (listing_id, available_date),
    -- Проверка защищает временную целостность записи.
    CONSTRAINT chk_listing_availability_days_update_not_before_create
        CHECK (last_update_date >= creation_date),
    -- Проверка обеспечивает консистентность override-пары:
    -- либо обе колонки пустые, либо обе заполнены и сумма положительная.
    CONSTRAINT chk_listing_availability_days_override_pair
        CHECK (
            (override_currency_id IS NULL AND override_in_minor IS NULL) OR
            (override_currency_id IS NOT NULL AND override_in_minor IS NOT NULL AND override_in_minor > 0)
            )
);

-- История изменений цен для аудита и аналитики.
CREATE TABLE price_history
(
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    listing_id          BIGINT              NOT NULL REFERENCES listings (id),
    source              price_change_source NOT NULL,
    -- Для day_override обязательно указываем день, для base_price всегда NULL.
    availability_day_id BIGINT REFERENCES listing_availability_days (id),
    old_currency_id     BIGINT REFERENCES currencies (id),
    new_currency_id     BIGINT REFERENCES currencies (id),
    old_amount_in_minor BIGINT,
    new_amount_in_minor BIGINT,
    changed_at          TIMESTAMPTZ         NOT NULL DEFAULT now(),
    changed_by_user_id  BIGINT REFERENCES users (id),
    reason              VARCHAR(512),
    -- Проверка гарантирует корректную привязку источника к availability_day_id.
    CONSTRAINT chk_price_history_source_link
        CHECK (
            (source = 'base_price' AND availability_day_id IS NULL) OR
            (source = 'day_override' AND availability_day_id IS NOT NULL)
            ),
    -- Проверка запрещает технически пустые записи истории без изменения суммы.
    CONSTRAINT chk_price_history_amount_change_present
        CHECK (old_amount_in_minor IS NOT NULL OR new_amount_in_minor IS NOT NULL),
    -- Проверка запрещает технически пустые записи истории без изменения/указания валюты.
    CONSTRAINT chk_price_history_currency_change_present
        CHECK (old_currency_id IS NOT NULL OR new_currency_id IS NOT NULL),
    -- Составной FK гарантирует, что availability_day_id принадлежит тому же listing_id,
    -- что и запись истории цен.
    CONSTRAINT fk_price_history_listing_day
        FOREIGN KEY (listing_id, availability_day_id)
            REFERENCES listing_availability_days (listing_id, id)
);

-- Триггер аудита: логируем изменения базовой цены автоматически.
CREATE OR REPLACE FUNCTION trg_base_prices_write_history()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF OLD.amount_in_minor IS DISTINCT FROM NEW.amount_in_minor
        OR OLD.currency_id IS DISTINCT FROM NEW.currency_id THEN
        INSERT INTO price_history (listing_id,
                                   source,
                                   availability_day_id,
                                   old_currency_id,
                                   new_currency_id,
                                   old_amount_in_minor,
                                   new_amount_in_minor,
                                   changed_at,
                                   changed_by_user_id,
                                   reason)
        VALUES (NEW.listing_id,
                'base_price',
                NULL,
                OLD.currency_id,
                NEW.currency_id,
                OLD.amount_in_minor,
                NEW.amount_in_minor,
                now(),
                NULL,
                'base price updated');
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_base_prices_write_history
    AFTER UPDATE
    ON base_prices
    FOR EACH ROW
EXECUTE FUNCTION trg_base_prices_write_history();

-- Триггер аудита: логируем изменения override-цены конкретного дня автоматически.
CREATE OR REPLACE FUNCTION trg_listing_availability_days_write_history()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF OLD.override_in_minor IS DISTINCT FROM NEW.override_in_minor
        OR OLD.override_currency_id IS DISTINCT FROM NEW.override_currency_id THEN
        INSERT INTO price_history (listing_id,
                                   source,
                                   availability_day_id,
                                   old_currency_id,
                                   new_currency_id,
                                   old_amount_in_minor,
                                   new_amount_in_minor,
                                   changed_at,
                                   changed_by_user_id,
                                   reason)
        VALUES (NEW.listing_id,
                'day_override',
                NEW.id,
                OLD.override_currency_id,
                NEW.override_currency_id,
                OLD.override_in_minor,
                NEW.override_in_minor,
                now(),
                NULL,
                'day override updated');
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_listing_availability_days_write_history
    AFTER UPDATE
    ON listing_availability_days
    FOR EACH ROW
EXECUTE FUNCTION trg_listing_availability_days_write_history();

-- Триггерная защита от физического удаления дат доступности.
-- Бизнес-правило ТЗ: даты не удаляются, а переводятся между статусами.
CREATE OR REPLACE FUNCTION trg_listing_availability_days_prevent_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN
    -- Этап 1: блокируем физическое удаление записи календаря.
    RAISE EXCEPTION
        'physical delete is forbidden for listing_availability_days (day_id=%). Use status update instead.',
        OLD.id;
END;
$$;

CREATE TRIGGER trg_listing_availability_days_prevent_delete
    BEFORE DELETE
    ON listing_availability_days
    FOR EACH ROW
EXECUTE FUNCTION trg_listing_availability_days_prevent_delete();
