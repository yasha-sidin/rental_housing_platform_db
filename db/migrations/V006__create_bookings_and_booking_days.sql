-- V006: бронирования и связь бронирования с выбранными днями доступности.
-- Зависимости: users (V003), listings (V004), currencies (V002), listing_availability_days (V005).
-- Важно: миграция фиксирует структурные инварианты БД (FK/UNIQUE/CHECK).
-- Конкурентная защита от овербукинга (атомарный hold дня, retries, идемпотентность)
-- является задачей backend-транзакций и должна быть реализована в прикладном сервисе.

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
    -- Уникальность пары нужна для составного FK из booking_days.
    -- Она позволяет декларативно проверить, что день и бронь относятся к одному listing.
    CONSTRAINT uq_bookings_id_listing_id UNIQUE (id, listing_id)
);

-- Связующая таблица "бронь -> выбранные дни".
-- Отдельная таблица нужна для надежной истории: даже после отмены/истечения
-- сохраняется факт, какие дни были привязаны к брони.
-- Допускается, что один и тот же день может исторически встречаться в разных бронированиях
-- (например, после EXPIRED/CANCELLED). Актуальная доступность дня контролируется статусами
-- в listing_availability_days и транзакционной логикой приложения.
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
