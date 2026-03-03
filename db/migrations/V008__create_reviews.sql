-- V008: отзывы по бронированиям.
-- Зависимости: bookings (V006).

CREATE TABLE reviews
(
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- Один отзыв на одно бронирование.
    booking_id      BIGINT UNIQUE NOT NULL REFERENCES bookings (id),
    mark            SMALLINT      NOT NULL,
    body            VARCHAR(2048),
    -- Признак модерации отзыва администратором.
    moderated       BOOLEAN       NOT NULL DEFAULT false,
    creation_date   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    moderation_date TIMESTAMPTZ,

    -- Проверка диапазона оценки (рейтинг от 1 до 5).
    CONSTRAINT chk_reviews_mark_range
        CHECK (mark BETWEEN 1 AND 5),

    -- Проверка запрещает пустой текст отзыва, если тело передано.
    CONSTRAINT chk_reviews_body_not_blank
        CHECK (body IS NULL OR btrim(body) <> ''),

    -- Проверка консистентности модерации:
    -- 1) не прошел модерацию -> дата модерации отсутствует;
    -- 2) прошел модерацию -> дата модерации задана и не раньше даты создания.
    CONSTRAINT chk_reviews_moderation_consistency
        CHECK (
            (moderated = false AND moderation_date IS NULL) OR
            (moderated = true AND moderation_date IS NOT NULL AND moderation_date >= creation_date)
            )
);

-- Триггерная проверка бизнес-инварианта:
-- отзыв допускается только по завершенному бронированию.
-- FOR UPDATE блокирует строку бронирования на время транзакции и исключает гонки,
-- когда статус брони меняется параллельно с созданием/изменением отзыва.
CREATE OR REPLACE FUNCTION trg_reviews_require_completed_booking()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
DECLARE
    v_booking_status booking_status;
BEGIN
    -- Этап 1: читаем статус бронирования, к которому привязывается отзыв.
    -- FOR UPDATE берёт блокировку строки бронирования до конца транзакции,
    -- чтобы параллельная смена статуса не нарушила проверку инварианта.
    SELECT b.status
    INTO v_booking_status
    FROM bookings b
    WHERE b.id = NEW.booking_id
    FOR UPDATE;

    -- Этап 1.1: дополнительная защита от неконсистентной ссылки.
    -- (обычно не сработает из-за FK, но даёт явную причину ошибки на уровне триггера).
    IF v_booking_status IS NULL THEN
        RAISE EXCEPTION 'booking_id=% does not exist', NEW.booking_id;
    END IF;

    -- Этап 2: ключевая бизнес-проверка.
    -- Разрешаем вставку/обновление отзыва только для завершённой брони.
    IF v_booking_status <> 'completed' THEN
        RAISE EXCEPTION
            'review is allowed only for completed booking, booking_id=% has status=%',
            NEW.booking_id, v_booking_status;
    END IF;

    -- Этап 3: все проверки пройдены, операция разрешена.
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_reviews_require_completed_booking
    BEFORE INSERT OR UPDATE
    ON reviews
    FOR EACH ROW
EXECUTE FUNCTION trg_reviews_require_completed_booking();
