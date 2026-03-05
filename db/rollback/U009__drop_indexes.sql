-- U009: откат индексов, созданных в V009__create_indexes.sql.
-- Используем IF EXISTS, чтобы откат был идемпотентным и не падал на частично примененной схеме.

-- Таблица countries
DROP INDEX IF EXISTS idx_countries_name_lower;

-- Таблица cities
DROP INDEX IF EXISTS idx_cities_name_lower;

-- Таблица addresses
DROP INDEX IF EXISTS idx_addresses_city_id;
DROP INDEX IF EXISTS idx_addresses_street_line1_trgm;
DROP INDEX IF EXISTS idx_addresses_city_id_postal_code;

-- Таблица currencies
DROP INDEX IF EXISTS idx_currencies_is_active_true;

-- Таблица users
DROP INDEX IF EXISTS idx_users_status;

-- Таблица role_permissions
DROP INDEX IF EXISTS idx_role_permissions_permission_id;

-- Таблица user_roles
DROP INDEX IF EXISTS idx_user_roles_role_id;

-- Таблица listings
DROP INDEX IF EXISTS idx_listings_owner_id;
DROP INDEX IF EXISTS idx_listings_object_type_id;
DROP INDEX IF EXISTS idx_listings_address_id;
DROP INDEX IF EXISTS idx_listings_status;

-- Таблица price_history
DROP INDEX IF EXISTS idx_price_history_listing_id;

-- Таблица bookings
DROP INDEX IF EXISTS idx_bookings_listing_id;
DROP INDEX IF EXISTS idx_bookings_created_by_user_creation_date_desc;
DROP INDEX IF EXISTS idx_bookings_status;

-- Таблица booking_days
DROP INDEX IF EXISTS idx_availability_day_id_listing_id_booking_id;

-- Таблица payments
DROP INDEX IF EXISTS idx_payments_status_session_expires_at;

-- Таблица reviews
DROP INDEX IF EXISTS idx_reviews_unmoderated_creation_date;

-- Удаляем расширение pg_trgm
DROP EXTENSION IF EXISTS pg_trgm;
