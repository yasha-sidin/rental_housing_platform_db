-- indexes_explain.sql
-- Домашнее задание: Индексы PostgreSQL.
--
-- Условие:
-- Создать индексы, показать EXPLAIN, реализовать полнотекстовый индекс,
-- индекс на часть таблицы или поле с функцией, индекс на несколько полей
-- и прокомментировать назначение индексов.
--
-- Перед финальным снятием планов рекомендуется:
--   make migrate-up
--   make seed-run
--   make seed-load N=1000
--
-- На очень маленькой базе PostgreSQL может выбрать Seq Scan, потому что чтение
-- всей таблицы дешевле обращения к индексу. Для показательных планов используем
-- load-данные и селективные условия.

SET search_path = application, public;

-- Обновляем статистику перед сравнением планов.
-- Это особенно важно после массовой загрузки данных через seed-load.
ANALYZE users;
ANALYZE listings;
ANALYZE addresses;
ANALYZE bookings;

-- ---------------------------------------------------------------------------
-- 1) Обычный btree индекс: idx_listings_owner_id.
--
-- Сценарий: владелец открывает список своих объявлений.
-- В плане ожидаем Index Scan или Bitmap Index Scan по idx_listings_owner_id.
-- ---------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    listing.id,
    listing.owner_id,
    listing.status,
    listing.description
FROM listings AS listing
WHERE listing.owner_id = (
    SELECT "user".id
    FROM users AS "user"
    WHERE "user".username = 'load_owner_500'
)
ORDER BY listing.id;

-- ---------------------------------------------------------------------------
-- 2) Полнотекстовый GIN индекс: idx_listings_description_fts.
--
-- Сценарий: пользователь ищет объявление по словам из описания.
-- В плане ожидаем Bitmap Index Scan по idx_listings_description_fts.
-- ---------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    listing.id,
    listing.description,
    listing.status
FROM listings AS listing
WHERE to_tsvector('simple', coalesce(listing.description, ''))
      @@ plainto_tsquery('simple', 'Manhattan');

-- ---------------------------------------------------------------------------
-- 3) Частичный составной индекс: idx_listings_active_capacity_rooms.
--
-- Сценарий: клиент ищет только активные объявления с нужной вместимостью и
-- количеством комнат. В индекс не попадают hidden/blocked объявления.
-- В плане ожидаем Index Scan или Bitmap Index Scan по idx_listings_active_capacity_rooms.
-- ---------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    count(*) AS matching_active_listings
FROM listings AS listing
WHERE listing.status = 'active'
  AND listing.capacity = 2
  AND listing.number_of_rooms = 1;

-- ---------------------------------------------------------------------------
-- 4) Индекс на поле с функцией: idx_addresses_city_id_postal_code.
--
-- Сценарий: поиск адреса внутри города по нормализованному почтовому индексу.
-- Индекс составной: city_id + lower(postal_code), поэтому условие должно
-- содержать city_id и то же выражение lower(postal_code).
-- ---------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    address.id,
    address.city_id,
    address.postal_code,
    address.street_line1
FROM addresses AS address
WHERE address.city_id = 20
  AND lower(address.postal_code) = lower('010500');

-- ---------------------------------------------------------------------------
-- 5) Составной индекс: idx_bookings_created_by_user_creation_date_desc.
--
-- Сценарий: гость смотрит историю своих бронирований от новых к старым.
-- В плане ожидаем Index Scan по idx_bookings_created_by_user_creation_date_desc,
-- потому что индекс начинается с created_by_user_id и уже отсортирован по
-- creation_date DESC.
-- ---------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    booking.id,
    booking.created_by_user_id,
    booking.status,
    booking.creation_date
FROM bookings AS booking
WHERE booking.created_by_user_id = (
    SELECT "user".id
    FROM users AS "user"
    WHERE "user".username = 'load_guest_500'
)
ORDER BY booking.creation_date DESC
LIMIT 20;
