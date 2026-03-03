-- V007: платежи по бронированиям.
-- Зависимости: bookings (V006), currencies (V002).

-- Статус жизненного цикла платежа.
CREATE TYPE payment_status AS ENUM (
    'initiated',
    'paid',
    'failed',
    'cancelled',
    'expired',
    'partially_refunded',
    'refunded'
);

CREATE TABLE payments
(
    id                                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- По текущей модели на одно бронирование допускается одна платежная сессия.
    -- Поэтому booking_id уникален.
    booking_id                          BIGINT UNIQUE       NOT NULL REFERENCES bookings (id),
    currency_id                         BIGINT              NOT NULL REFERENCES currencies (id),
    -- Сумма платежа в minor units (например, центы), чтобы избежать ошибок округления.
    amount_in_minor                     BIGINT              NOT NULL,
    -- Накопленная сумма возврата в minor units.
    refunded_amount_in_minor            BIGINT              NOT NULL DEFAULT 0,
    status                              payment_status      NOT NULL,
    initiated_date                      TIMESTAMPTZ         NOT NULL DEFAULT now(),
    -- Идентификатор платежной сессии у внешнего провайдера.
    -- Уникальность нужна для идемпотентной обработки повторных callback/webhook событий.
    provider_payment_session_id         VARCHAR(512) UNIQUE NOT NULL,
    provider_payment_session_expires_at TIMESTAMPTZ         NOT NULL,
    last_update_date                    TIMESTAMPTZ         NOT NULL DEFAULT now(),

    -- Проверка исключает нулевой и отрицательный платеж.
    CONSTRAINT chk_payments_amount_positive
        CHECK (amount_in_minor > 0),
    -- Проверка гарантирует, что сумма возврата не выходит за границы [0; amount].
    CONSTRAINT chk_payments_refunded_amount_range
        CHECK (refunded_amount_in_minor >= 0 AND refunded_amount_in_minor <= amount_in_minor),
    -- Проверка временной целостности записи.
    CONSTRAINT chk_payments_update_not_before_initiated
        CHECK (last_update_date >= initiated_date),
    -- Проверка гарантирует, что срок жизни сессии наступает после ее инициации.
    CONSTRAINT chk_payments_session_expires_after_initiated
        CHECK (provider_payment_session_expires_at > initiated_date)
);