-- U010: откат V010.
--
-- Скрипт возвращает прикладные объекты обратно в public и удаляет роли app_*,
-- созданные в V010.
--
-- Операционное требование:
-- V010 делает app_owner владельцем объектов application. Поэтому rollback нужно
-- запускать ролью, которая может вернуть ownership на CURRENT_USER, либо superuser.

-- ---------------------------------------------------------------------------
-- 1) Сбрасываем role-level search_path.
--
-- Эти настройки были записаны на сами роли app_* в V010. Перед удалением ролей
-- их нужно убрать.
-- ---------------------------------------------------------------------------
ALTER ROLE app_readonly RESET search_path;
ALTER ROLE app_readwrite RESET search_path;
ALTER ROLE app_owner RESET search_path;

-- ---------------------------------------------------------------------------
-- 2) Сбрасываем function-level search_path.
--
-- V010 закрепила trigger-функции на application, public, pg_temp.
-- Перед переносом функций обратно в public возвращаем поведение по умолчанию.
-- ---------------------------------------------------------------------------
ALTER FUNCTION application.trg_listings_prevent_delete() RESET search_path;
ALTER FUNCTION application.trg_base_prices_write_history() RESET search_path;
ALTER FUNCTION application.trg_listing_availability_days_write_history() RESET search_path;
ALTER FUNCTION application.trg_listing_availability_days_prevent_delete() RESET search_path;
ALTER FUNCTION application.trg_bookings_validate_status_transition() RESET search_path;
ALTER FUNCTION application.trg_listing_availability_days_block_status_change_on_active_hold() RESET search_path;
ALTER FUNCTION application.trg_booking_days_prevent_active_overlap() RESET search_path;
ALTER FUNCTION application.trg_payments_require_not_expired_booking() RESET search_path;
ALTER FUNCTION application.trg_reviews_require_completed_booking() RESET search_path;

-- ---------------------------------------------------------------------------
-- 3) Удаляем default privileges, созданные в V010.
--
-- Default privileges хранятся как настройки создателя будущих объектов.
-- V010 настраивала CURRENT_USER и app_owner, поэтому rollback обращает оба набора.
-- ---------------------------------------------------------------------------
ALTER DEFAULT PRIVILEGES IN SCHEMA application
    REVOKE SELECT ON TABLES FROM app_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA application
    REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLES FROM app_readwrite;

ALTER DEFAULT PRIVILEGES IN SCHEMA application
    REVOKE SELECT ON SEQUENCES FROM app_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA application
    REVOKE USAGE, SELECT, UPDATE ON SEQUENCES FROM app_readwrite;

ALTER DEFAULT PRIVILEGES
    GRANT EXECUTE ON FUNCTIONS TO PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA application
    REVOKE ALL PRIVILEGES ON FUNCTIONS FROM app_owner;

ALTER DEFAULT PRIVILEGES
    GRANT USAGE ON TYPES TO PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA application
    REVOKE USAGE ON TYPES FROM app_readonly, app_readwrite, app_owner;

ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA application
    REVOKE SELECT ON TABLES FROM app_readonly;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA application
    REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLES FROM app_readwrite;

ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA application
    REVOKE SELECT ON SEQUENCES FROM app_readonly;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA application
    REVOKE USAGE, SELECT, UPDATE ON SEQUENCES FROM app_readwrite;

ALTER DEFAULT PRIVILEGES FOR ROLE app_owner
    GRANT EXECUTE ON FUNCTIONS TO PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA application
    REVOKE ALL PRIVILEGES ON FUNCTIONS FROM app_owner;

ALTER DEFAULT PRIVILEGES FOR ROLE app_owner
    GRANT USAGE ON TYPES TO PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA application
    REVOKE USAGE ON TYPES FROM app_readonly, app_readwrite, app_owner;

-- ---------------------------------------------------------------------------
-- 4) Снимаем явные права, выданные в V010.
--
-- DROP ROLE может упасть, если у роли остаются grants на существующие объекты.
-- Поэтому сначала снимаем права app_* со схемы, таблиц, sequences, типов и функций.
-- ---------------------------------------------------------------------------
REVOKE SELECT ON ALL TABLES IN SCHEMA application FROM app_readonly;
REVOKE SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA application FROM app_readwrite;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA application FROM app_owner;

REVOKE SELECT ON ALL SEQUENCES IN SCHEMA application FROM app_readonly;
REVOKE USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA application FROM app_readwrite;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA application FROM app_owner;

REVOKE USAGE ON TYPE application.user_status FROM app_readonly, app_readwrite, app_owner;
REVOKE USAGE ON TYPE application.listing_publication_status FROM app_readonly, app_readwrite, app_owner;
REVOKE USAGE ON TYPE application.photo_extension FROM app_readonly, app_readwrite, app_owner;
REVOKE USAGE ON TYPE application.availability_status FROM app_readonly, app_readwrite, app_owner;
REVOKE USAGE ON TYPE application.price_change_source FROM app_readonly, app_readwrite, app_owner;
REVOKE USAGE ON TYPE application.booking_status FROM app_readonly, app_readwrite, app_owner;
REVOKE USAGE ON TYPE application.payment_status FROM app_readonly, app_readwrite, app_owner;

REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA application FROM app_owner;

REVOKE USAGE ON SCHEMA application FROM app_readonly;
REVOKE USAGE ON SCHEMA application FROM app_readwrite;
REVOKE USAGE, CREATE ON SCHEMA application FROM app_owner;

-- ---------------------------------------------------------------------------
-- 5) Возвращаем ownership с app_owner на CURRENT_USER.
--
-- V010 сделала app_owner реальным владельцем схемы и прикладных объектов.
-- Перед удалением app_owner нужно передать ownership другой роли.
-- CURRENT_USER используется потому, что rollback обычно выполняет migration-user.
-- ---------------------------------------------------------------------------
ALTER SCHEMA application OWNER TO CURRENT_USER;

ALTER TYPE application.user_status OWNER TO CURRENT_USER;
ALTER TYPE application.listing_publication_status OWNER TO CURRENT_USER;
ALTER TYPE application.photo_extension OWNER TO CURRENT_USER;
ALTER TYPE application.availability_status OWNER TO CURRENT_USER;
ALTER TYPE application.price_change_source OWNER TO CURRENT_USER;
ALTER TYPE application.booking_status OWNER TO CURRENT_USER;
ALTER TYPE application.payment_status OWNER TO CURRENT_USER;

ALTER TABLE application.roles OWNER TO CURRENT_USER;
ALTER TABLE application.permissions OWNER TO CURRENT_USER;
ALTER TABLE application.object_types OWNER TO CURRENT_USER;
ALTER TABLE application.countries OWNER TO CURRENT_USER;
ALTER TABLE application.cities OWNER TO CURRENT_USER;
ALTER TABLE application.addresses OWNER TO CURRENT_USER;
ALTER TABLE application.currencies OWNER TO CURRENT_USER;
ALTER TABLE application.users OWNER TO CURRENT_USER;
ALTER TABLE application.role_permissions OWNER TO CURRENT_USER;
ALTER TABLE application.user_roles OWNER TO CURRENT_USER;
ALTER TABLE application.listings OWNER TO CURRENT_USER;
ALTER TABLE application.photos OWNER TO CURRENT_USER;
ALTER TABLE application.listing_photos OWNER TO CURRENT_USER;
ALTER TABLE application.base_prices OWNER TO CURRENT_USER;
ALTER TABLE application.listing_availability_days OWNER TO CURRENT_USER;
ALTER TABLE application.price_history OWNER TO CURRENT_USER;
ALTER TABLE application.bookings OWNER TO CURRENT_USER;
ALTER TABLE application.booking_days OWNER TO CURRENT_USER;
ALTER TABLE application.payments OWNER TO CURRENT_USER;
ALTER TABLE application.reviews OWNER TO CURRENT_USER;

ALTER SEQUENCE application.roles_id_seq OWNER TO CURRENT_USER;
ALTER SEQUENCE application.permissions_id_seq OWNER TO CURRENT_USER;
ALTER SEQUENCE application.object_types_id_seq OWNER TO CURRENT_USER;
ALTER SEQUENCE application.countries_id_seq OWNER TO CURRENT_USER;
ALTER SEQUENCE application.cities_id_seq OWNER TO CURRENT_USER;
ALTER SEQUENCE application.addresses_id_seq OWNER TO CURRENT_USER;
ALTER SEQUENCE application.currencies_id_seq OWNER TO CURRENT_USER;
ALTER SEQUENCE application.users_id_seq OWNER TO CURRENT_USER;
ALTER SEQUENCE application.listings_id_seq OWNER TO CURRENT_USER;
ALTER SEQUENCE application.photos_id_seq OWNER TO CURRENT_USER;
ALTER SEQUENCE application.base_prices_id_seq OWNER TO CURRENT_USER;
ALTER SEQUENCE application.listing_availability_days_id_seq OWNER TO CURRENT_USER;
ALTER SEQUENCE application.price_history_id_seq OWNER TO CURRENT_USER;
ALTER SEQUENCE application.bookings_id_seq OWNER TO CURRENT_USER;
ALTER SEQUENCE application.booking_days_id_seq OWNER TO CURRENT_USER;
ALTER SEQUENCE application.payments_id_seq OWNER TO CURRENT_USER;
ALTER SEQUENCE application.reviews_id_seq OWNER TO CURRENT_USER;

ALTER FUNCTION application.trg_listings_prevent_delete() OWNER TO CURRENT_USER;
ALTER FUNCTION application.trg_base_prices_write_history() OWNER TO CURRENT_USER;
ALTER FUNCTION application.trg_listing_availability_days_write_history() OWNER TO CURRENT_USER;
ALTER FUNCTION application.trg_listing_availability_days_prevent_delete() OWNER TO CURRENT_USER;
ALTER FUNCTION application.trg_bookings_validate_status_transition() OWNER TO CURRENT_USER;
ALTER FUNCTION application.trg_listing_availability_days_block_status_change_on_active_hold() OWNER TO CURRENT_USER;
ALTER FUNCTION application.trg_booking_days_prevent_active_overlap() OWNER TO CURRENT_USER;
ALTER FUNCTION application.trg_payments_require_not_expired_booking() OWNER TO CURRENT_USER;
ALTER FUNCTION application.trg_reviews_require_completed_booking() OWNER TO CURRENT_USER;

-- ---------------------------------------------------------------------------
-- 6) Переносим trigger-функции обратно в public.
--
-- Это возвращает namespace к состоянию до V010.
-- ---------------------------------------------------------------------------
ALTER FUNCTION application.trg_listings_prevent_delete() SET SCHEMA public;
ALTER FUNCTION application.trg_base_prices_write_history() SET SCHEMA public;
ALTER FUNCTION application.trg_listing_availability_days_write_history() SET SCHEMA public;
ALTER FUNCTION application.trg_listing_availability_days_prevent_delete() SET SCHEMA public;
ALTER FUNCTION application.trg_bookings_validate_status_transition() SET SCHEMA public;
ALTER FUNCTION application.trg_listing_availability_days_block_status_change_on_active_hold() SET SCHEMA public;
ALTER FUNCTION application.trg_booking_days_prevent_active_overlap() SET SCHEMA public;
ALTER FUNCTION application.trg_payments_require_not_expired_booking() SET SCHEMA public;
ALTER FUNCTION application.trg_reviews_require_completed_booking() SET SCHEMA public;

-- ---------------------------------------------------------------------------
-- 7) Переносим таблицы обратно в public.
--
-- Их индексы, constraints и owned identity sequences переезжают вместе с таблицами.
-- ---------------------------------------------------------------------------
ALTER TABLE application.roles SET SCHEMA public;
ALTER TABLE application.permissions SET SCHEMA public;
ALTER TABLE application.object_types SET SCHEMA public;
ALTER TABLE application.countries SET SCHEMA public;
ALTER TABLE application.cities SET SCHEMA public;
ALTER TABLE application.addresses SET SCHEMA public;
ALTER TABLE application.currencies SET SCHEMA public;
ALTER TABLE application.users SET SCHEMA public;
ALTER TABLE application.role_permissions SET SCHEMA public;
ALTER TABLE application.user_roles SET SCHEMA public;
ALTER TABLE application.listings SET SCHEMA public;
ALTER TABLE application.photos SET SCHEMA public;
ALTER TABLE application.listing_photos SET SCHEMA public;
ALTER TABLE application.base_prices SET SCHEMA public;
ALTER TABLE application.listing_availability_days SET SCHEMA public;
ALTER TABLE application.price_history SET SCHEMA public;
ALTER TABLE application.bookings SET SCHEMA public;
ALTER TABLE application.booking_days SET SCHEMA public;
ALTER TABLE application.payments SET SCHEMA public;
ALTER TABLE application.reviews SET SCHEMA public;

-- ---------------------------------------------------------------------------
-- 8) Переносим enum-типы обратно в public.
-- ---------------------------------------------------------------------------
ALTER TYPE application.user_status SET SCHEMA public;
ALTER TYPE application.listing_publication_status SET SCHEMA public;
ALTER TYPE application.photo_extension SET SCHEMA public;
ALTER TYPE application.availability_status SET SCHEMA public;
ALTER TYPE application.price_change_source SET SCHEMA public;
ALTER TYPE application.booking_status SET SCHEMA public;
ALTER TYPE application.payment_status SET SCHEMA public;

-- ---------------------------------------------------------------------------
-- 9) Возвращаем стандартные PUBLIC-права для функций и enum-типов.
--
-- V010 сняла PUBLIC EXECUTE/USAGE после переноса объектов в application.
-- До V010 эти объекты жили в public со стандартными правами PostgreSQL на функции
-- и типы, поэтому rollback возвращает эти права явно.
-- ---------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.trg_listings_prevent_delete() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.trg_base_prices_write_history() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.trg_listing_availability_days_write_history() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.trg_listing_availability_days_prevent_delete() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.trg_bookings_validate_status_transition() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.trg_listing_availability_days_block_status_change_on_active_hold() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.trg_booking_days_prevent_active_overlap() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.trg_payments_require_not_expired_booking() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.trg_reviews_require_completed_booking() TO PUBLIC;

GRANT USAGE ON TYPE public.user_status TO PUBLIC;
GRANT USAGE ON TYPE public.listing_publication_status TO PUBLIC;
GRANT USAGE ON TYPE public.photo_extension TO PUBLIC;
GRANT USAGE ON TYPE public.availability_status TO PUBLIC;
GRANT USAGE ON TYPE public.price_change_source TO PUBLIC;
GRANT USAGE ON TYPE public.booking_status TO PUBLIC;
GRANT USAGE ON TYPE public.payment_status TO PUBLIC;

-- ---------------------------------------------------------------------------
-- 10) Удаляем application.
--
-- После переноса функций, таблиц и типов схема должна быть пустой.
-- ---------------------------------------------------------------------------
DROP SCHEMA IF EXISTS application;

-- ---------------------------------------------------------------------------
-- 11) Удаляем membership и сами групповые роли.
--
-- В V010 app_owner был выдан CURRENT_USER, чтобы migration-user мог выступать
-- владельцем миграций. Здесь это членство снимается перед DROP ROLE.
-- ---------------------------------------------------------------------------
DO
$$
BEGIN
    EXECUTE format('REVOKE app_owner FROM %I', CURRENT_USER);
END;
$$;
REVOKE app_readwrite FROM app_owner;
REVOKE app_readonly FROM app_readwrite;

DROP ROLE IF EXISTS app_owner;
DROP ROLE IF EXISTS app_readwrite;
DROP ROLE IF EXISTS app_readonly;
