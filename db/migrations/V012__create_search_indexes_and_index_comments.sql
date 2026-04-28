-- V012: индексы для домашнего задания по PostgreSQL indexes.
--
-- Контекст:
-- - V009 уже создает базовый набор btree/GIN/partial/function/composite индексов.
-- - V010 переносит прикладные объекты в схему application.
-- - V011 переносит существующие индексы в tablespace rental_index_ts.
--
-- Эта миграция добавляет недостающий полнотекстовый индекс, отдельный практический
-- частичный составной индекс для поиска активных объявлений и фиксирует объектные
-- COMMENT ON INDEX для явных индексов проекта.

SET search_path = application, public;

-- ---------------------------------------------------------------------------
-- 1) Полнотекстовый поиск по описанию объявления.
--
-- Индекс ускоряет запросы вида:
--   WHERE to_tsvector('simple', coalesce(description, ''))
--         @@ plainto_tsquery('simple', 'Manhattan')
--
-- Важно: выражение в запросе должно совпадать с выражением в индексе, иначе
-- PostgreSQL не сможет использовать expression GIN index.
-- ---------------------------------------------------------------------------
CREATE INDEX idx_listings_description_fts
    ON application.listings
        USING GIN (to_tsvector('simple', coalesce(description, '')))
    TABLESPACE rental_index_ts;

COMMENT ON INDEX application.idx_listings_description_fts IS
    'GIN индекс полнотекстового поиска по описанию объявления. Используется для поиска по словам в listings.description через to_tsvector/plainto_tsquery.';

-- ---------------------------------------------------------------------------
-- 2) Частичный составной индекс под клиентский поиск активных объявлений.
--
-- Индекс хранит только опубликованные объявления status = active, поэтому он
-- меньше полного индекса по listings и лучше соответствует пользовательскому
-- сценарию поиска жилья по вместимости и числу комнат.
--
-- Пример запроса:
--   WHERE status = 'active' AND capacity = 2 AND number_of_rooms = 1
-- ---------------------------------------------------------------------------
CREATE INDEX idx_listings_active_capacity_rooms
    ON application.listings (capacity, number_of_rooms)
    TABLESPACE rental_index_ts
    WHERE status = 'active';

COMMENT ON INDEX application.idx_listings_active_capacity_rooms IS
    'Частичный составной btree индекс для поиска активных объявлений по вместимости и количеству комнат.';

-- ---------------------------------------------------------------------------
-- 3) Объектные комментарии к явным индексам из V009.
--
-- SQL-комментарии в файле миграции полезны человеку при чтении репозитория.
-- COMMENT ON INDEX дополнительно сохраняет назначение индекса в каталоге самой БД,
-- поэтому его можно увидеть через psql \d+ или запросы к pg_description.
-- ---------------------------------------------------------------------------
COMMENT ON INDEX application.idx_countries_name_lower IS
    'Функциональный btree индекс для регистронезависимого поиска страны по lower(name).';

COMMENT ON INDEX application.idx_cities_name_lower IS
    'Функциональный btree индекс для регистронезависимого поиска города по lower(name).';

COMMENT ON INDEX application.idx_addresses_city_id IS
    'Btree индекс для быстрого поиска адресов по городу и ускорения соединений addresses -> cities.';

COMMENT ON INDEX application.idx_addresses_street_line1_trgm IS
    'GIN trigram индекс для поиска адреса по подстроке в street_line1, например через ILIKE.';

COMMENT ON INDEX application.idx_addresses_city_id_postal_code IS
    'Составной btree expression индекс для поиска адресов внутри города по lower(postal_code).';

COMMENT ON INDEX application.idx_currencies_is_active_true IS
    'Частичный btree индекс по активным валютам. В индекс попадают только строки с is_active = true.';

COMMENT ON INDEX application.idx_users_status IS
    'Btree индекс для фильтрации пользователей по статусу аккаунта.';

COMMENT ON INDEX application.idx_role_permissions_permission_id IS
    'Btree индекс для обратного поиска ролей, которым выдано конкретное разрешение.';

COMMENT ON INDEX application.idx_user_roles_role_id IS
    'Btree индекс для поиска пользователей, которым назначена конкретная роль.';

COMMENT ON INDEX application.idx_listings_owner_id IS
    'Btree индекс для выборки всех объявлений конкретного владельца.';

COMMENT ON INDEX application.idx_listings_object_type_id IS
    'Btree индекс для фильтрации объявлений по типу объекта недвижимости.';

COMMENT ON INDEX application.idx_listings_address_id IS
    'Btree индекс для поиска объявлений по адресу и ускорения соединений listings -> addresses.';

COMMENT ON INDEX application.idx_listings_status IS
    'Btree индекс для фильтрации объявлений по статусу публикации.';

COMMENT ON INDEX application.idx_price_history_listing_id IS
    'Btree индекс для просмотра истории изменения цены по конкретному объявлению.';

COMMENT ON INDEX application.idx_bookings_listing_id IS
    'Btree индекс для поиска бронирований конкретного объявления.';

COMMENT ON INDEX application.idx_bookings_created_by_user_creation_date_desc IS
    'Составной btree индекс для ленты бронирований гостя с сортировкой по дате создания от новых к старым.';

COMMENT ON INDEX application.idx_bookings_status IS
    'Btree индекс для фильтрации бронирований по статусу жизненного цикла.';

COMMENT ON INDEX application.idx_availability_day_id_listing_id_booking_id IS
    'Составной btree индекс для ускорения триггерной проверки пересечения активных бронирований по дню доступности.';

COMMENT ON INDEX application.idx_payments_status_session_expires_at IS
    'Составной btree индекс для поиска платежных сессий по статусу и времени истечения.';

COMMENT ON INDEX application.idx_reviews_unmoderated_creation_date IS
    'Частичный btree индекс очереди модерации отзывов. В индекс попадают только отзывы moderated = false.';
