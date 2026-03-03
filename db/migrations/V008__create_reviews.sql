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

-- Важно для бизнес-правила ТЗ:
-- Отзыв должен создаваться только по завершенному бронированию (booking.status = 'completed').
-- В текущей модели это правило контролируется на стороне приложения/сервиса.
-- При необходимости правило можно усилить триггером в БД в отдельной миграции.