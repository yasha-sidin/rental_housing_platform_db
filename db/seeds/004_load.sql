-- 004_load.sql
-- Массовая генерация данных для нагрузочного тестирования.
-- Использует переменную psql rows (задается через -v rows=<N>).
--
-- В отличие от базовых сидов, этот скрипт масштабирует сразу несколько таблиц:
-- users, user_roles, addresses, listings, photos, listing_photos, base_prices,
-- listing_availability_days, bookings, booking_days, payments и price_history.

BEGIN;

-- 0) Параметры нагрузочного запуска.
-- rows_count: сколько "пакетов" сущностей генерировать.
-- days_per_listing: сколько дат доступности на каждый load-listing создавать.
-- Ограничиваем дни сверху, чтобы объём не рос квадратично слишком агрессивно.
WITH params AS (SELECT :rows::int            AS rows_count,
                       LEAST(:rows::int, 30) AS days_per_listing)
SELECT 1
FROM params;

-- 1) Массовые пользователи (владельцы + гости), идемпотентно по username.
INSERT INTO users (username, phone_number, email, status)
SELECT 'load_owner_' || gs::text,
       '+2888' || lpad(gs::text, 7, '0'),
       'load_owner_' || gs::text || '@example.com',
       'active'::user_status
FROM generate_series(1, :rows) AS gs
ON CONFLICT (username) DO NOTHING;

INSERT INTO users (username, phone_number, email, status)
SELECT 'load_guest_' || gs::text,
       '+2999' || lpad(gs::text, 7, '0'),
       'load_guest_' || gs::text || '@example.com',
       'active'::user_status
FROM generate_series(1, :rows) AS gs
ON CONFLICT (username) DO NOTHING;

-- 2) Ролевые привязки для load-пользователей.
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
         JOIN roles r ON r.name = 'owner'
WHERE u.username LIKE 'load_owner_%'
ON CONFLICT (user_id, role_id) DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
         JOIN roles r ON r.name = 'guest'
WHERE u.username LIKE 'load_guest_%'
ON CONFLICT (user_id, role_id) DO NOTHING;

-- 3) Массовые адреса.
-- Распределяем адреса по доступным городам циклически через modulo.
WITH city_pool AS (SELECT c.id,
                          row_number() OVER (ORDER BY c.id) AS rn,
                          count(*) OVER ()                  AS cnt
                   FROM cities c),
     gen AS (SELECT gs AS idx
             FROM generate_series(1, :rows) AS gs)
INSERT
INTO addresses (city_id, street_line1, street_line2, region, postal_code, link)
SELECT cp.id,
       'Load Street ' || g.idx,
       'Load Building ' || ((g.idx % 50) + 1),
       'LOAD',
       lpad((10000 + g.idx)::text, 6, '0'),
       'https://maps.example/load-' || g.idx
FROM gen g
         JOIN city_pool cp
              ON cp.rn = ((g.idx - 1) % cp.cnt) + 1
WHERE NOT EXISTS (SELECT 1
                  FROM addresses a
                  WHERE a.city_id = cp.id
                    AND a.street_line1 = 'Load Street ' || g.idx);

-- 4) Массовые объявления (один load-listing на одного load-owner).
-- object_type выбираем циклически.
WITH type_pool AS (SELECT ot.id,
                          row_number() OVER (ORDER BY ot.id) AS rn,
                          count(*) OVER ()                   AS cnt
                   FROM object_types ot),
     gen AS (SELECT gs AS idx
             FROM generate_series(1, :rows) AS gs)
INSERT
INTO listings (owner_id, object_type_id, address_id, capacity, number_of_rooms, description, status)
SELECT u.id,
       tp.id,
       a.id,
       ((g.idx % 6) + 1) AS capacity,
       ((g.idx % 4) + 1) AS number_of_rooms,
       'Load listing #' || g.idx,
       'active'::listing_publication_status
FROM gen g
         JOIN users u
              ON u.username = 'load_owner_' || g.idx
         JOIN addresses a
              ON a.street_line1 = 'Load Street ' || g.idx
         JOIN type_pool tp
              ON tp.rn = ((g.idx - 1) % tp.cnt) + 1
WHERE NOT EXISTS (SELECT 1
                  FROM listings l
                  WHERE l.description = 'Load listing #' || g.idx);

-- 5) Массовые фото и привязка к объявлениям (по одному фото на listing).
INSERT INTO photos (extension, link)
SELECT CASE WHEN (gs % 2) = 0 THEN 'jpeg'::photo_extension ELSE 'png'::photo_extension END,
       'https://images.example/load-listing-' || gs || '.img'
FROM generate_series(1, :rows) AS gs
ON CONFLICT (link) DO NOTHING;

INSERT INTO listing_photos (listing_id, photo_id, slot)
SELECT l.id, p.id, 1
FROM generate_series(1, :rows) AS gs
         JOIN listings l ON l.description = 'Load listing #' || gs
         JOIN photos p ON p.link = 'https://images.example/load-listing-' || gs || '.img'
ON CONFLICT DO NOTHING;

-- 6) Базовые цены на load-listings.
-- Валюту выбираем циклически из нескольких активных вариантов.
WITH currency_pool AS (SELECT c.id,
                              row_number() OVER (ORDER BY c.id) AS rn,
                              count(*) OVER ()                  AS cnt
                       FROM currencies c
                       WHERE c.code IN ('USD', 'EUR', 'GBP', 'RUB')),
     gen AS (SELECT gs AS idx
             FROM generate_series(1, :rows) AS gs)
INSERT
INTO base_prices (currency_id, amount_in_minor, listing_id)
SELECT cp.id,
       (10000 + (g.idx % 9000))::bigint AS amount_in_minor,
       l.id
FROM gen g
         JOIN listings l
              ON l.description = 'Load listing #' || g.idx
         JOIN currency_pool cp
              ON cp.rn = ((g.idx - 1) % cp.cnt) + 1
ON CONFLICT (listing_id) DO UPDATE
    SET currency_id      = EXCLUDED.currency_id,
        amount_in_minor  = EXCLUDED.amount_in_minor,
        last_update_date = now();

-- 7) Массовая доступность на дальний горизонт дат
-- (чтобы не пересекаться с базовыми/scenario данными).
WITH params AS (SELECT LEAST(:rows::int, 30) AS days_per_listing)
INSERT
INTO listing_availability_days (available_date, status, listing_id)
SELECT (current_date + 120 + offs)::date,
       'available'::availability_status,
       l.id
FROM listings l
         JOIN params p ON true
         CROSS JOIN generate_series(1, p.days_per_listing) AS offs
WHERE l.description LIKE 'Load listing #%'
ON CONFLICT (listing_id, available_date) DO NOTHING;

-- 8) Нагрузочные бронирования:
-- создаем бронь примерно на половину новых дат доступности load-listings.
--
-- Важные принципы:
-- - берем только статус available, чтобы не конфликтовать с уже занятыми датами;
-- - используем разные booking_status для реалистичности;
-- - соблюдаем check-ограничения (например, cancellation_reason для cancelled);
-- - привязываем дни через booking_days.
CREATE TEMP TABLE load_booking_plan
(
    plan_id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    listing_id           BIGINT         NOT NULL,
    day_id               BIGINT         NOT NULL,
    guest_id             BIGINT         NOT NULL,
    owner_id             BIGINT         NOT NULL,
    currency_id          BIGINT         NOT NULL,
    amount_in_minor      BIGINT         NOT NULL,
    booking_expires_at   TIMESTAMPTZ    NOT NULL,
    target_status        booking_status NOT NULL,
    cancelled_by_user_id BIGINT,
    cancellation_reason  VARCHAR(512),
    booking_id           BIGINT
);

CREATE TEMP TABLE load_guest_pool
(
    rn       BIGINT PRIMARY KEY,
    guest_id BIGINT NOT NULL
);

INSERT INTO load_guest_pool (rn, guest_id)
SELECT row_number() OVER (ORDER BY u.id), u.id
FROM users u
WHERE u.username LIKE 'load_guest_%';

WITH guest_meta AS (SELECT count(*)::bigint AS cnt
                    FROM load_guest_pool),
     candidate_days AS (SELECT d.id AS day_id,
                               d.listing_id,
                               d.available_date
                        FROM listing_availability_days d
                                 JOIN listings l ON l.id = d.listing_id
                        WHERE l.description LIKE 'Load listing #%'
                          AND d.status = 'available'
                          AND d.available_date BETWEEN current_date + 121 AND current_date + 150
                          -- Берем примерно половину дат по каждому листингу.
                          AND ((d.available_date - (current_date + 120)) % 2 = 0)),
     plan_source AS (SELECT cd.listing_id,
                            cd.day_id,
                            l.owner_id,
                            gp.guest_id,
                            bp.currency_id,
                            bp.amount_in_minor,
                            -- Стабильный "seed" для распределения статусов/сумм без оконных функций.
                            (cd.day_id + cd.listing_id) AS distribution_seed
                     FROM candidate_days cd
                              JOIN listings l ON l.id = cd.listing_id
                              JOIN base_prices bp ON bp.listing_id = l.id
                              JOIN guest_meta gm ON gm.cnt > 0
                              JOIN load_guest_pool gp
                                   ON gp.rn = ((cd.day_id - 1) % gm.cnt) + 1)
INSERT
INTO load_booking_plan
(listing_id,
 day_id,
 guest_id,
 owner_id,
 currency_id,
 amount_in_minor,
 booking_expires_at,
 target_status,
 cancelled_by_user_id,
 cancellation_reason)
SELECT ps.listing_id,
       ps.day_id,
       ps.guest_id,
       ps.owner_id,
       ps.currency_id,
       -- Небольшая вариативность итоговой суммы.
       ps.amount_in_minor + ((ps.distribution_seed % 5) * 100),
       -- Уникализируем expires_at микросекундами, оставаясь в 5-минутном окне.
       now() + interval '4 minutes' + ((ps.day_id % 1000000)::text || ' microseconds')::interval,
       CASE (ps.distribution_seed % 6)
           WHEN 0 THEN 'completed'::booking_status
           WHEN 1 THEN 'confirmed'::booking_status
           WHEN 2 THEN 'payment_pending'::booking_status
           WHEN 3 THEN 'created'::booking_status
           WHEN 4 THEN 'cancelled'::booking_status
           ELSE 'expired'::booking_status
           END,
       CASE
           WHEN (ps.distribution_seed % 6) = 4
               THEN CASE WHEN (ps.distribution_seed % 2) = 0 THEN ps.guest_id ELSE ps.owner_id END
           ELSE NULL
           END,
       CASE
           WHEN (ps.distribution_seed % 6) = 4
               THEN CASE
                        WHEN (ps.distribution_seed % 2) = 0
                            THEN 'guest changed plans (load)'
                        ELSE 'owner maintenance issue (load)'
               END
           ELSE NULL
           END
FROM plan_source ps;

-- Вставка заголовков бронирований.
INSERT INTO bookings
(listing_id,
 created_by_user_id,
 guests_count,
 total_amount_currency_id,
 total_amount_in_minor,
 status,
 cancelled_by_user_id,
 cancellation_reason,
 booking_expires_at)
SELECT p.listing_id,
       p.guest_id,
       ((p.plan_id % 4) + 1)::int,
       p.currency_id,
       p.amount_in_minor,
       -- На этапе привязки дней бронь должна быть "активной" для триггера booking_days.
       -- Поэтому итоговые неактивные статусы выставим позже отдельным UPDATE.
       CASE
           WHEN p.target_status IN ('confirmed', 'completed') THEN 'confirmed'::booking_status
           WHEN p.target_status = 'payment_pending' THEN 'payment_pending'::booking_status
           ELSE 'created'::booking_status
           END,
       NULL,
       NULL,
       p.booking_expires_at
FROM load_booking_plan p;

-- Связываем план с реально созданными booking_id.
UPDATE load_booking_plan p
SET booking_id = b.id
FROM bookings b
WHERE b.listing_id = p.listing_id
  AND b.created_by_user_id = p.guest_id
  AND b.booking_expires_at = p.booking_expires_at
  AND b.status = CASE
                     WHEN p.target_status IN ('confirmed', 'completed') THEN 'confirmed'::booking_status
                     WHEN p.target_status = 'payment_pending' THEN 'payment_pending'::booking_status
                     ELSE 'created'::booking_status
    END
  AND b.total_amount_in_minor = p.amount_in_minor;

-- Привязываем выбранные даты к бронированиям.
INSERT INTO booking_days (booking_id, availability_day_id, listing_id)
SELECT p.booking_id, p.day_id, p.listing_id
FROM load_booking_plan p
WHERE p.booking_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- После успешной привязки дат переводим брони в целевые статусы.
UPDATE bookings b
SET status               = p.target_status,
    cancelled_by_user_id = CASE WHEN p.target_status = 'cancelled' THEN p.cancelled_by_user_id ELSE NULL END,
    cancellation_reason  = CASE WHEN p.target_status = 'cancelled' THEN p.cancellation_reason ELSE NULL END,
    last_update_date     = now()
FROM load_booking_plan p
WHERE b.id = p.booking_id
  AND b.status IS DISTINCT FROM p.target_status;

-- Обновляем статус даты в зависимости от статуса брони:
-- completed/confirmed -> booked
-- created/payment_pending -> held
-- cancelled/expired -> оставляем available.
UPDATE listing_availability_days d
SET status           = CASE
                           WHEN p.target_status IN ('completed', 'confirmed') THEN 'booked'::availability_status
                           WHEN p.target_status IN ('created', 'payment_pending') THEN 'held'::availability_status
                           ELSE 'available'::availability_status
    END,
    last_update_date = now()
FROM load_booking_plan p
WHERE p.day_id = d.id
  AND p.booking_id IS NOT NULL;

-- Платежи для нагрузочных бронирований.
-- Моделируем разные payment_status:
-- - completed/confirmed => paid (иногда partially_refunded);
-- - payment_pending/created => initiated;
-- - cancelled => cancelled/refunded;
-- - expired => expired.
INSERT INTO payments
(booking_id,
 currency_id,
 amount_in_minor,
 refunded_amount_in_minor,
 status,
 provider_payment_session_id,
 provider_payment_session_expires_at)
SELECT p.booking_id,
       p.currency_id,
       p.amount_in_minor,
       CASE
           WHEN p.target_status = 'confirmed' AND (p.plan_id % 5) = 0 THEN p.amount_in_minor / 3
           WHEN p.target_status = 'cancelled' AND (p.plan_id % 3) = 0 THEN p.amount_in_minor
           ELSE 0
           END AS refunded_amount_in_minor,
       CASE
           WHEN p.target_status = 'completed' THEN 'paid'::payment_status
           WHEN p.target_status = 'confirmed' AND (p.plan_id % 5) = 0 THEN 'partially_refunded'::payment_status
           WHEN p.target_status = 'confirmed' THEN 'paid'::payment_status
           WHEN p.target_status IN ('payment_pending', 'created') THEN 'initiated'::payment_status
           WHEN p.target_status = 'cancelled' AND (p.plan_id % 3) = 0 THEN 'refunded'::payment_status
           WHEN p.target_status = 'cancelled' THEN 'cancelled'::payment_status
           ELSE 'expired'::payment_status
           END AS payment_status,
       'load-payment-' || p.booking_id,
       now() + interval '5 minutes'
FROM load_booking_plan p
WHERE p.booking_id IS NOT NULL
  -- Оставляем часть created-бронирований без платежа для реалистичности.
  AND NOT (p.target_status = 'created' AND (p.plan_id % 2) = 1)
ON CONFLICT (booking_id) DO NOTHING;

-- 9) Триггерная генерация истории цен (price_history):
-- обновляем часть load-цен, чтобы появились записи аудита изменений.
UPDATE base_prices bp
SET amount_in_minor  = bp.amount_in_minor + 111,
    last_update_date = now()
FROM listings l
WHERE bp.listing_id = l.id
  AND l.description LIKE 'Load listing #%'
  AND (l.id % 10 = 0);

COMMIT;
