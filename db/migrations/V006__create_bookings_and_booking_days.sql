-- V006: бронирования и связь бронирования с выбранными днями доступности.
-- Зависимости: users (V003), listings (V004), currencies (V002), listing_availability_days (V005).

-- Статус жизненного цикла бронирования.
CREATE TYPE booking_status AS ENUM ('created', 'payment_pending', 'confirmed', 'expired', 'cancelled', 'completed');

-- Основная таблица бронирований.
CREATE TABLE bookings
(
    id                       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- Явно храним listing_id, чтобы бронь была привязана только к одному объекту.
    listing_id               BIGINT         NOT NULL REFERENCES listings (id),
    -- Пользователь, который создал бронь (гость).
    created_by_user_id       BIGINT         NOT NULL REFERENCES users (id),
    guests_count             INT            NOT NULL,
    total_amount_currency_id BIGINT         NOT NULL REFERENCES currencies (id),
    -- Сумма в minor units (например, центы), чтобы избежать ошибок округления.
    total_amount_in_minor    BIGINT         NOT NULL,
    status                   booking_status NOT NULL,
    -- Пользователь, выполнивший отмену бронирования (если применимо).
    cancelled_by_user_id     BIGINT REFERENCES users (id),
    -- Причина отмены бронирования. Обязательна для статуса cancelled.
    cancellation_reason      VARCHAR(512),
    creation_date            TIMESTAMPTZ    NOT NULL DEFAULT now(),
    last_update_date         TIMESTAMPTZ    NOT NULL DEFAULT now(),
    -- Время истечения окна оплаты до создания платежной сессии.
    booking_expires_at       TIMESTAMPTZ    NOT NULL,
    -- Проверка гарантирует, что срок истечения бронирования:
    -- 1) строго позже времени создания;
    -- 2) не превышает окно удержания в 5 минут по требованиям ТЗ.
    CONSTRAINT chk_bookings_expires_after_create
        CHECK (
            booking_expires_at > creation_date AND
            booking_expires_at <= creation_date + INTERVAL '5 minutes'
            ),
    -- Проверка исключает нулевое/отрицательное количество гостей.
    CONSTRAINT chk_bookings_guests_count_positive
        CHECK (guests_count > 0),
    -- Проверка исключает нулевую/отрицательную стоимость бронирования.
    CONSTRAINT chk_bookings_total_amount_positive
        CHECK (total_amount_in_minor > 0),
    -- Проверка защищает временную целостность записи.
    CONSTRAINT chk_bookings_update_not_before_create
        CHECK (last_update_date >= creation_date),
    -- Если бронь отменена, причина обязательна и не пустая.
    -- Если бронь не отменена, причину не храним, чтобы не накапливать "мусорные" значения.
    CONSTRAINT chk_bookings_cancel_reason_required
        CHECK (
            (status = 'cancelled' AND cancellation_reason IS NOT NULL AND btrim(cancellation_reason) <> '') OR
            (status <> 'cancelled' AND cancellation_reason IS NULL)
            ),
    -- Уникальность пары нужна для составного FK из booking_days.
    -- Она позволяет декларативно проверить, что день и бронь относятся к одному listing.
    CONSTRAINT uq_bookings_id_listing_id UNIQUE (id, listing_id)
);

-- Триггер контроля переходов статуса брони.
-- Ключевое правило: запрет отмены бронирования из статуса payment_pending.
CREATE OR REPLACE FUNCTION trg_bookings_validate_status_transition()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS
$$
BEGIN
    -- Этап 1: применяем проверку только если статус действительно меняется.
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        -- Этап 2: запрещаем переход payment_pending -> cancelled.
        IF OLD.status = 'payment_pending' AND NEW.status = 'cancelled' THEN
            RAISE EXCEPTION
                'booking_id=% cannot be cancelled while status is payment_pending',
                OLD.id;
        END IF;
    END IF;

    -- Этап 3: возврат новой версии строки после успешной проверки.
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_bookings_validate_status_transition
    BEFORE UPDATE
    ON bookings
    FOR EACH ROW
EXECUTE FUNCTION trg_bookings_validate_status_transition();

-- Связующая таблица "бронь -> выбранные дни".
-- Отдельная таблица нужна для надежной истории: даже после отмены/истечения
-- сохраняется факт, какие дни были привязаны к брони.
CREATE TABLE booking_days
(
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id          BIGINT      NOT NULL,
    availability_day_id BIGINT      NOT NULL,
    -- Храним listing_id в связующей таблице специально для декларативной проверки согласованности.
    -- Это устраняет потребность в триггере на сверку "день и бронь от одного объекта".
    listing_id          BIGINT      NOT NULL,
    creation_date       TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Проверка запрещает повторное добавление одного и того же дня в рамках одной брони.
    CONSTRAINT uq_booking_days_booking_day UNIQUE (booking_id, availability_day_id),
    -- FK гарантирует, что booking_id существует и принадлежит именно этому listing_id.
    CONSTRAINT fk_booking_days_booking_listing
        FOREIGN KEY (booking_id, listing_id)
            REFERENCES bookings (id, listing_id),
    -- FK гарантирует, что availability_day_id существует и относится к тому же listing_id.
    CONSTRAINT fk_booking_days_listing_day
        FOREIGN KEY (listing_id, availability_day_id)
            REFERENCES listing_availability_days (listing_id, id)
);

-- Триггерная проверка на смену статуса дня доступности при активном удержании.
-- Правило: если день удерживается активной бронью (статус HELD), его нельзя
-- переводить в статус AVAILABLE/BLOCKED до завершения удерживающей брони.
CREATE OR REPLACE FUNCTION trg_listing_availability_days_block_status_change_on_active_hold()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_has_active_hold BOOLEAN;
BEGIN
    -- Этап 1: выполняем проверку только при фактической смене статуса.
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        -- Этап 2: контролируем только сценарий "день в HOLD пытаются перевести
        -- в состояние, разрывающее удержание для бронирования".
        IF OLD.status = 'held' AND NEW.status IN ('available', 'blocked') THEN
            -- Этап 3: проверяем, есть ли активная бронь, которая удерживает этот день.
            SELECT EXISTS (SELECT 1
                           FROM booking_days bd
                                    JOIN bookings b ON b.id = bd.booking_id
                           WHERE bd.availability_day_id = OLD.id
                             AND b.status IN ('created', 'payment_pending', 'confirmed'))
            INTO v_has_active_hold;

            -- Этап 4: при наличии активного удержания смена статуса запрещена.
            IF v_has_active_hold THEN
                RAISE EXCEPTION
                    'cannot change availability day status while it is held by active booking, day_id=%',
                    OLD.id;
            END IF;
        END IF;
    END IF;

    -- Этап 5: проверка пройдена, возвращаем новую версию строки.
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_listing_availability_days_block_status_change_on_active_hold
    BEFORE UPDATE
    ON listing_availability_days
    FOR EACH ROW
EXECUTE FUNCTION trg_listing_availability_days_block_status_change_on_active_hold();

-- Триггерная проверка для защиты от двойного активного бронирования одного дня.
-- Логика:
-- 1) Блокируем строку дня доступности через FOR UPDATE, чтобы сериализовать конкурирующие попытки.
-- 2) Разрешаем привязку дня только к активной брони (created/payment_pending/confirmed).
-- 3) Проверяем, что тот же день уже не привязан к другой активной брони.
CREATE OR REPLACE FUNCTION trg_booking_days_prevent_active_overlap()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_booking_status booking_status;
    v_listing_status listing_publication_status;
    v_day_exists     BOOLEAN;
    v_conflict       BOOLEAN;
BEGIN
    -- Этап 1: читаем текущий статус бронирования, к которому пытаются привязать день.
    SELECT b.status
    INTO v_booking_status
    FROM bookings b
    WHERE b.id = NEW.booking_id;

    -- Этап 1.1: защита от неконсистентной вставки с несуществующим booking_id.
    IF v_booking_status IS NULL THEN
        RAISE EXCEPTION 'booking_id=% does not exist', NEW.booking_id;
    END IF;

    -- Этап 1.2: день можно привязать только к активному бронированию.
    -- Это исключает повторное изменение состава дат у завершенных/отмененных/протухших броней.
    IF v_booking_status NOT IN ('created', 'payment_pending', 'confirmed') THEN
        RAISE EXCEPTION
            'booking_id=% has non-active status=% and cannot receive availability days',
            NEW.booking_id, v_booking_status;
    END IF;

    -- Этап 2: проверяем, что объект размещения активен в момент привязки дня.
    -- FOR UPDATE защищает от конкурентной смены статуса объявления в соседней транзакции.
    SELECT l.status
    INTO v_listing_status
    FROM listings l
    WHERE l.id = NEW.listing_id
        FOR UPDATE;

    -- Этап 2.1: если объект не найден или не активен, привязка дня недопустима.
    IF v_listing_status IS NULL OR v_listing_status <> 'active' THEN
        RAISE EXCEPTION
            'listing_id=% must be active for booking day assignment',
            NEW.listing_id;
    END IF;

    -- Этап 3: проверяем существование дня и берем lock на строку дня.
    -- FOR UPDATE сериализует конкурентные попытки работы с одним и тем же днем.
    SELECT EXISTS (SELECT 1
                   FROM listing_availability_days lad
                   WHERE lad.id = NEW.availability_day_id
                     AND lad.listing_id = NEW.listing_id
                       FOR UPDATE)
    INTO v_day_exists;

    -- Этап 3.1: если дня нет у указанного listing, операция недопустима.
    IF NOT v_day_exists THEN
        RAISE EXCEPTION
            'availability_day_id=% does not exist for listing_id=%',
            NEW.availability_day_id, NEW.listing_id;
    END IF;

    -- Этап 4: ищем конфликт с другими активными бронированиями.
    -- Условие bd.booking_id <> NEW.booking_id исключает текущую бронь из сравнения.
    SELECT EXISTS (SELECT 1
                   FROM booking_days bd
                            JOIN bookings b ON b.id = bd.booking_id
                   WHERE bd.availability_day_id = NEW.availability_day_id
                     AND bd.listing_id = NEW.listing_id
                     AND bd.booking_id <> NEW.booking_id
                     AND b.status IN ('created', 'payment_pending', 'confirmed'))
    INTO v_conflict;

    -- Этап 4.1: если конфликт найден, запрещаем вставку/обновление.
    IF v_conflict THEN
        RAISE EXCEPTION
            'availability_day_id=% is already linked to another active booking',
            NEW.availability_day_id;
    END IF;

    -- Этап 5: все проверки пройдены, строку можно сохранять.
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_booking_days_prevent_active_overlap
    BEFORE INSERT OR UPDATE
    ON booking_days
    FOR EACH ROW
EXECUTE FUNCTION trg_booking_days_prevent_active_overlap();
