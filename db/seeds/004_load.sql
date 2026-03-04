-- 004_load.sql
-- Массовая генерация данных для нагрузочного тестирования.
-- Использует переменную psql rows (задается через -v rows=<N>).
--
-- В отличие от базовых сидов, этот скрипт масштабирует сразу несколько таблиц:
-- users, user_roles, addresses, listings, photos, listing_photos, base_prices,
-- listing_availability_days и price_history (через триггер обновления цен).

BEGIN;

-- 0) Параметры нагрузочного запуска.
-- rows_count: сколько "пакетов" сущностей генерировать.
-- days_per_listing: сколько дат доступности на каждый load-listing создавать.
-- Ограничиваем дни сверху, чтобы объём не рос квадратично слишком агрессивно.
WITH params AS (
    SELECT :rows::int AS rows_count,
           LEAST(:rows::int, 30) AS days_per_listing
)
SELECT 1 FROM params;

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
WITH city_pool AS (
    SELECT c.id,
           row_number() OVER (ORDER BY c.id) AS rn,
           count(*) OVER () AS cnt
    FROM cities c
),
gen AS (
    SELECT gs AS idx
    FROM generate_series(1, :rows) AS gs
)
INSERT INTO addresses (city_id, street_line1, street_line2, region, postal_code, link)
SELECT cp.id,
       'Load Street ' || g.idx,
       'Load Building ' || ((g.idx % 50) + 1),
       'LOAD',
       lpad((10000 + g.idx)::text, 6, '0'),
       'https://maps.example/load-' || g.idx
FROM gen g
JOIN city_pool cp
  ON cp.rn = ((g.idx - 1) % cp.cnt) + 1
WHERE NOT EXISTS (
    SELECT 1
    FROM addresses a
    WHERE a.city_id = cp.id
      AND a.street_line1 = 'Load Street ' || g.idx
);

-- 4) Массовые объявления (один load-listing на одного load-owner).
-- object_type выбираем циклически.
WITH type_pool AS (
    SELECT ot.id,
           row_number() OVER (ORDER BY ot.id) AS rn,
           count(*) OVER () AS cnt
    FROM object_types ot
),
gen AS (
    SELECT gs AS idx
    FROM generate_series(1, :rows) AS gs
)
INSERT INTO listings (owner_id, object_type_id, address_id, capacity, number_of_rooms, description, status)
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
WHERE NOT EXISTS (
    SELECT 1
    FROM listings l
    WHERE l.description = 'Load listing #' || g.idx
);

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
WITH currency_pool AS (
    SELECT c.id,
           row_number() OVER (ORDER BY c.id) AS rn,
           count(*) OVER () AS cnt
    FROM currencies c
    WHERE c.code IN ('USD', 'EUR', 'GBP', 'RUB')
),
gen AS (
    SELECT gs AS idx
    FROM generate_series(1, :rows) AS gs
)
INSERT INTO base_prices (currency_id, amount_in_minor, listing_id)
SELECT cp.id,
       (10000 + (g.idx % 9000))::bigint AS amount_in_minor,
       l.id
FROM gen g
JOIN listings l
  ON l.description = 'Load listing #' || g.idx
JOIN currency_pool cp
  ON cp.rn = ((g.idx - 1) % cp.cnt) + 1
ON CONFLICT (listing_id) DO UPDATE
SET currency_id = EXCLUDED.currency_id,
    amount_in_minor = EXCLUDED.amount_in_minor,
    last_update_date = now();

-- 7) Массовая доступность на дальний горизонт дат
-- (чтобы не пересекаться с базовыми/scenario данными).
WITH params AS (
    SELECT LEAST(:rows::int, 30) AS days_per_listing
)
INSERT INTO listing_availability_days (available_date, status, listing_id)
SELECT (current_date + 120 + offs)::date,
       'available'::availability_status,
       l.id
FROM listings l
JOIN params p ON true
CROSS JOIN generate_series(1, p.days_per_listing) AS offs
WHERE l.description LIKE 'Load listing #%'
ON CONFLICT (listing_id, available_date) DO NOTHING;

-- 8) Триггерная генерация истории цен (price_history):
-- обновляем часть load-цен, чтобы появились записи аудита изменений.
UPDATE base_prices bp
SET amount_in_minor = bp.amount_in_minor + 111,
    last_update_date = now()
FROM listings l
WHERE bp.listing_id = l.id
  AND l.description LIKE 'Load listing #%'
  AND (l.id % 10 = 0);

COMMIT;
