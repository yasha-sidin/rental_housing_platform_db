-- V010: выделение прикладной схемы application и настройка ролей доступа.
--
-- Зачем нужна эта миграция:
-- 1) Все предыдущие миграции создавали объекты без явного указания схемы.
--    Из-за стандартного search_path PostgreSQL размещал их в схеме public.
-- 2) public - это общая схема по умолчанию. Она удобна для простых проектов,
--    но плохо подходит как граница приложения и модели доступа.
-- 3) application становится явным местом для бизнес-таблиц, enum-типов и
--    trigger-функций проекта.
-- 4) Права выдаются групповым ролям, а не напрямую login-пользователям.
--    Реальных пользователей нужно подключать к этим ролям через GRANT role TO user.
--
-- Операционное требование:
-- миграция создает роли и меняет владельцев объектов. Ее нужно запускать ролью,
-- которая имеет право CREATE ROLE и право менять владельцев объектов, либо superuser.

-- ---------------------------------------------------------------------------
-- 1) Создаем отдельную схему application.
--
-- Схему public мы не удаляем. Это стандартная схема PostgreSQL, и в ней могут
-- оставаться extension-объекты или служебные объекты. Мы переносим из public только
-- прикладные объекты проекта и дальше используем application как основную схему.
-- ---------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS application;

-- ---------------------------------------------------------------------------
-- 2) Создаем групповые роли доступа.
--
-- Роли NOLOGIN: они не предназначены для прямого подключения к БД.
-- Это именно роли-группы, которые назначаются реальным login-пользователям.
--
-- app_readonly:
--   роль аналитика/отчетности, только чтение данных.
--
-- app_readwrite:
--   роль приложения или разработчика, чтение и обычная запись данных.
--
-- app_owner:
--   роль миграций/владельца, владеет объектами и может выполнять DDL.
--
-- Примеры назначения реальным пользователям:
--   GRANT app_readonly TO analyst_login;
--   GRANT app_readwrite TO developer_login;
--   GRANT app_owner TO migration_login;
-- ---------------------------------------------------------------------------
DO
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_owner') THEN
        CREATE ROLE app_owner NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_readwrite') THEN
        CREATE ROLE app_readwrite NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_readonly') THEN
        CREATE ROLE app_readonly NOLOGIN;
    END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- 3) Настраиваем наследование ролей.
--
-- app_readwrite наследует все права app_readonly.
-- app_owner наследует все права app_readwrite и дополнительно становится владельцем
-- схемы/объектов ниже по миграции.
--
-- В итоге пользователю обычно достаточно выдать одну верхнеуровневую роль.
-- ---------------------------------------------------------------------------
GRANT app_readonly TO app_readwrite;
GRANT app_readwrite TO app_owner;

-- Роль, которая запускает миграции сейчас, также получает app_owner.
-- Это делает текущего исполнителя практической migration-ролью и позволяет будущим
-- миграциям выполнять SET ROLE app_owner, если migration tool это поддерживает.
DO
$$
BEGIN
    EXECUTE format('GRANT app_owner TO %I', CURRENT_USER);
END;
$$;

-- ---------------------------------------------------------------------------
-- 4) Переносим enum-типы из public в application.
--
-- Типы - это не данные таблиц, но они часть прикладной модели: колонки используют
-- эти enum, а роли должны иметь USAGE на типах, чтобы вставлять/фильтровать значения.
-- ---------------------------------------------------------------------------
ALTER TYPE user_status SET SCHEMA application;
ALTER TYPE listing_publication_status SET SCHEMA application;
ALTER TYPE photo_extension SET SCHEMA application;
ALTER TYPE availability_status SET SCHEMA application;
ALTER TYPE price_change_source SET SCHEMA application;
ALTER TYPE booking_status SET SCHEMA application;
ALTER TYPE payment_status SET SCHEMA application;

-- ---------------------------------------------------------------------------
-- 5) Переносим таблицы из public в application.
--
-- ALTER TABLE ... SET SCHEMA переносит не только таблицу. Вместе с ней переезжают
-- связанные индексы, constraints и identity sequences, принадлежащие колонкам таблицы.
-- Данные таблиц не переписываются; меняется только namespace объекта.
-- ---------------------------------------------------------------------------
ALTER TABLE roles SET SCHEMA application;
ALTER TABLE permissions SET SCHEMA application;
ALTER TABLE object_types SET SCHEMA application;
ALTER TABLE countries SET SCHEMA application;
ALTER TABLE cities SET SCHEMA application;
ALTER TABLE addresses SET SCHEMA application;
ALTER TABLE currencies SET SCHEMA application;
ALTER TABLE users SET SCHEMA application;
ALTER TABLE role_permissions SET SCHEMA application;
ALTER TABLE user_roles SET SCHEMA application;
ALTER TABLE listings SET SCHEMA application;
ALTER TABLE photos SET SCHEMA application;
ALTER TABLE listing_photos SET SCHEMA application;
ALTER TABLE base_prices SET SCHEMA application;
ALTER TABLE listing_availability_days SET SCHEMA application;
ALTER TABLE price_history SET SCHEMA application;
ALTER TABLE bookings SET SCHEMA application;
ALTER TABLE booking_days SET SCHEMA application;
ALTER TABLE payments SET SCHEMA application;
ALTER TABLE reviews SET SCHEMA application;

-- ---------------------------------------------------------------------------
-- 6) Переносим trigger-функции из public в application.
--
-- Триггеры продолжат ссылаться на те же функции: мы переносим сами function objects.
-- Так бизнес-логика, связанная с таблицами, остается в той же схеме application.
-- ---------------------------------------------------------------------------
ALTER FUNCTION trg_listings_prevent_delete() SET SCHEMA application;
ALTER FUNCTION trg_base_prices_write_history() SET SCHEMA application;
ALTER FUNCTION trg_listing_availability_days_write_history() SET SCHEMA application;
ALTER FUNCTION trg_listing_availability_days_prevent_delete() SET SCHEMA application;
ALTER FUNCTION trg_bookings_validate_status_transition() SET SCHEMA application;
ALTER FUNCTION trg_listing_availability_days_block_status_change_on_active_hold() SET SCHEMA application;
ALTER FUNCTION trg_booking_days_prevent_active_overlap() SET SCHEMA application;
ALTER FUNCTION trg_payments_require_not_expired_booking() SET SCHEMA application;
ALTER FUNCTION trg_reviews_require_completed_booking() SET SCHEMA application;

-- ---------------------------------------------------------------------------
-- 7) Фиксируем search_path для trigger-функций.
--
-- В PL/pgSQL-коде функций есть неполные имена таблиц и типов: bookings,
-- booking_status и т.п. Если сессия вызывающего имеет другой search_path, такие
-- имена могут резолвиться не туда. Function-level search_path делает поведение
-- триггеров стабильным.
--
-- pg_temp оставляем последним, чтобы временные объекты не могли затенить объекты
-- application.
-- ---------------------------------------------------------------------------
ALTER FUNCTION application.trg_listings_prevent_delete() SET search_path = application, public, pg_temp;
ALTER FUNCTION application.trg_base_prices_write_history() SET search_path = application, public, pg_temp;
ALTER FUNCTION application.trg_listing_availability_days_write_history() SET search_path = application, public, pg_temp;
ALTER FUNCTION application.trg_listing_availability_days_prevent_delete() SET search_path = application, public, pg_temp;
ALTER FUNCTION application.trg_bookings_validate_status_transition() SET search_path = application, public, pg_temp;
ALTER FUNCTION application.trg_listing_availability_days_block_status_change_on_active_hold() SET search_path = application, public, pg_temp;
ALTER FUNCTION application.trg_booking_days_prevent_active_overlap() SET search_path = application, public, pg_temp;
ALTER FUNCTION application.trg_payments_require_not_expired_booking() SET search_path = application, public, pg_temp;
ALTER FUNCTION application.trg_reviews_require_completed_booking() SET search_path = application, public, pg_temp;

-- ---------------------------------------------------------------------------
-- 8) Закрываем неявный доступ к application.
--
-- PUBLIC здесь означает "все роли базы", а не схему public.
-- Сначала снимаем доступ со всех, затем выдаем права только через app_* роли.
--
-- USAGE на схему:
--   роль может резолвить имена объектов внутри схемы.
--
-- CREATE на схему:
--   роль может создавать новые объекты в этой схеме.
-- ---------------------------------------------------------------------------
REVOKE ALL ON SCHEMA application FROM PUBLIC;
GRANT USAGE ON SCHEMA application TO app_readonly;
GRANT USAGE ON SCHEMA application TO app_readwrite;
GRANT USAGE, CREATE ON SCHEMA application TO app_owner;

-- ---------------------------------------------------------------------------
-- 9) Права на таблицы и sequences.
--
-- app_readonly:
--   только SELECT. Подходит для аналитиков и отчетности.
--
-- app_readwrite:
--   SELECT/INSERT/UPDATE/DELETE. Это обычный прикладной DML.
--   TRUNCATE, REFERENCES и TRIGGER не выдаем: это сильнее, чем "читать/писать".
--
-- sequences:
--   app_readwrite нужен USAGE/UPDATE, потому что identity/default значения используют
--   sequences при INSERT.
--   app_readonly получает SELECT только для просмотра состояния sequence при нужде.
-- ---------------------------------------------------------------------------
GRANT SELECT ON ALL TABLES IN SCHEMA application TO app_readonly;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA application TO app_readwrite;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA application TO app_owner;

GRANT SELECT ON ALL SEQUENCES IN SCHEMA application TO app_readonly;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA application TO app_readwrite;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA application TO app_owner;

-- ---------------------------------------------------------------------------
-- 10) Права на enum-типы.
--
-- PostgreSQL по умолчанию дает USAGE на типы роли PUBLIC. Здесь мы делаем модель
-- явной: типы application доступны через app_* роли, а не всем ролям базы.
-- ---------------------------------------------------------------------------
REVOKE USAGE ON TYPE application.user_status FROM PUBLIC;
REVOKE USAGE ON TYPE application.listing_publication_status FROM PUBLIC;
REVOKE USAGE ON TYPE application.photo_extension FROM PUBLIC;
REVOKE USAGE ON TYPE application.availability_status FROM PUBLIC;
REVOKE USAGE ON TYPE application.price_change_source FROM PUBLIC;
REVOKE USAGE ON TYPE application.booking_status FROM PUBLIC;
REVOKE USAGE ON TYPE application.payment_status FROM PUBLIC;

GRANT USAGE ON TYPE application.user_status TO app_readonly, app_readwrite, app_owner;
GRANT USAGE ON TYPE application.listing_publication_status TO app_readonly, app_readwrite, app_owner;
GRANT USAGE ON TYPE application.photo_extension TO app_readonly, app_readwrite, app_owner;
GRANT USAGE ON TYPE application.availability_status TO app_readonly, app_readwrite, app_owner;
GRANT USAGE ON TYPE application.price_change_source TO app_readonly, app_readwrite, app_owner;
GRANT USAGE ON TYPE application.booking_status TO app_readonly, app_readwrite, app_owner;
GRANT USAGE ON TYPE application.payment_status TO app_readonly, app_readwrite, app_owner;

-- ---------------------------------------------------------------------------
-- 11) Права на функции.
--
-- PostgreSQL по умолчанию дает EXECUTE на функции роли PUBLIC.
-- Trigger-функции здесь считаются внутренней реализацией таблиц, поэтому прямой
-- EXECUTE для readonly/readwrite не выдаем. Триггеры при этом продолжат их вызывать.
-- ---------------------------------------------------------------------------
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA application FROM PUBLIC;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA application TO app_owner;

-- ---------------------------------------------------------------------------
-- 12) Default privileges для будущих объектов.
--
-- ALTER DEFAULT PRIVILEGES привязан к создателю объектов. Поэтому настраиваем два
-- сценария:
-- - CURRENT_USER: если migration tool продолжит создавать объекты напрямую;
-- - app_owner: если будущие миграции будут выполняться после SET ROLE app_owner.
--
-- Для таблиц и sequences PostgreSQL позволяет задать schema-specific default grants.
-- Для функций и типов есть глобальные дефолтные PUBLIC-права (EXECUTE/USAGE).
-- Их нельзя снять только в одной схеме, поэтому ниже они снимаются на уровне
-- создателя объектов, а schema-specific grants добавляются только ролям app_*.
--
-- Без этого блока новые объекты в application могли бы "выпасть" из модели доступа.
-- ---------------------------------------------------------------------------
ALTER DEFAULT PRIVILEGES IN SCHEMA application
    GRANT SELECT ON TABLES TO app_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA application
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_readwrite;

ALTER DEFAULT PRIVILEGES IN SCHEMA application
    GRANT SELECT ON SEQUENCES TO app_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA application
    GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO app_readwrite;

ALTER DEFAULT PRIVILEGES
    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA application
    GRANT ALL PRIVILEGES ON FUNCTIONS TO app_owner;

ALTER DEFAULT PRIVILEGES
    REVOKE USAGE ON TYPES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA application
    GRANT USAGE ON TYPES TO app_readonly, app_readwrite, app_owner;

ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA application
    GRANT SELECT ON TABLES TO app_readonly;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA application
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_readwrite;

ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA application
    GRANT SELECT ON SEQUENCES TO app_readonly;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA application
    GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO app_readwrite;

ALTER DEFAULT PRIVILEGES FOR ROLE app_owner
    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA application
    GRANT ALL PRIVILEGES ON FUNCTIONS TO app_owner;

ALTER DEFAULT PRIVILEGES FOR ROLE app_owner
    REVOKE USAGE ON TYPES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA application
    GRANT USAGE ON TYPES TO app_readonly, app_readwrite, app_owner;

-- ---------------------------------------------------------------------------
-- 13) search_path для групповых ролей.
--
-- Это фиксирует ожидаемый порядок поиска объектов: сначала application, потом public.
--
-- Важный нюанс PostgreSQL:
-- app_* роли сейчас NOLOGIN. Реальные login-пользователи, которым выдали app_* через
-- GRANT, не наследуют role-level search_path автоматически при подключении.
-- Для конкретных login-пользователей нужно либо обращаться к объектам явно:
--   application.users
-- либо отдельно настроить search_path:
--   ALTER ROLE analyst_login SET search_path = application, public;
-- ---------------------------------------------------------------------------
ALTER ROLE app_readonly SET search_path = application, public;
ALTER ROLE app_readwrite SET search_path = application, public;
ALTER ROLE app_owner SET search_path = application, public;

-- ---------------------------------------------------------------------------
-- 14) Передаем ownership роли app_owner.
--
-- GRANT ALL PRIVILEGES не равен владению объектом.
-- Ownership дает возможность делать DDL: ALTER TABLE, ALTER TYPE, DROP FUNCTION и т.п.
-- После этого блока app_owner становится настоящим владельцем схемы application и
-- всех прикладных объектов.
-- ---------------------------------------------------------------------------
ALTER SCHEMA application OWNER TO app_owner;

ALTER TYPE application.user_status OWNER TO app_owner;
ALTER TYPE application.listing_publication_status OWNER TO app_owner;
ALTER TYPE application.photo_extension OWNER TO app_owner;
ALTER TYPE application.availability_status OWNER TO app_owner;
ALTER TYPE application.price_change_source OWNER TO app_owner;
ALTER TYPE application.booking_status OWNER TO app_owner;
ALTER TYPE application.payment_status OWNER TO app_owner;

ALTER TABLE application.roles OWNER TO app_owner;
ALTER TABLE application.permissions OWNER TO app_owner;
ALTER TABLE application.object_types OWNER TO app_owner;
ALTER TABLE application.countries OWNER TO app_owner;
ALTER TABLE application.cities OWNER TO app_owner;
ALTER TABLE application.addresses OWNER TO app_owner;
ALTER TABLE application.currencies OWNER TO app_owner;
ALTER TABLE application.users OWNER TO app_owner;
ALTER TABLE application.role_permissions OWNER TO app_owner;
ALTER TABLE application.user_roles OWNER TO app_owner;
ALTER TABLE application.listings OWNER TO app_owner;
ALTER TABLE application.photos OWNER TO app_owner;
ALTER TABLE application.listing_photos OWNER TO app_owner;
ALTER TABLE application.base_prices OWNER TO app_owner;
ALTER TABLE application.listing_availability_days OWNER TO app_owner;
ALTER TABLE application.price_history OWNER TO app_owner;
ALTER TABLE application.bookings OWNER TO app_owner;
ALTER TABLE application.booking_days OWNER TO app_owner;
ALTER TABLE application.payments OWNER TO app_owner;
ALTER TABLE application.reviews OWNER TO app_owner;

ALTER SEQUENCE application.roles_id_seq OWNER TO app_owner;
ALTER SEQUENCE application.permissions_id_seq OWNER TO app_owner;
ALTER SEQUENCE application.object_types_id_seq OWNER TO app_owner;
ALTER SEQUENCE application.countries_id_seq OWNER TO app_owner;
ALTER SEQUENCE application.cities_id_seq OWNER TO app_owner;
ALTER SEQUENCE application.addresses_id_seq OWNER TO app_owner;
ALTER SEQUENCE application.currencies_id_seq OWNER TO app_owner;
ALTER SEQUENCE application.users_id_seq OWNER TO app_owner;
ALTER SEQUENCE application.listings_id_seq OWNER TO app_owner;
ALTER SEQUENCE application.photos_id_seq OWNER TO app_owner;
ALTER SEQUENCE application.base_prices_id_seq OWNER TO app_owner;
ALTER SEQUENCE application.listing_availability_days_id_seq OWNER TO app_owner;
ALTER SEQUENCE application.price_history_id_seq OWNER TO app_owner;
ALTER SEQUENCE application.bookings_id_seq OWNER TO app_owner;
ALTER SEQUENCE application.booking_days_id_seq OWNER TO app_owner;
ALTER SEQUENCE application.payments_id_seq OWNER TO app_owner;
ALTER SEQUENCE application.reviews_id_seq OWNER TO app_owner;

ALTER FUNCTION application.trg_listings_prevent_delete() OWNER TO app_owner;
ALTER FUNCTION application.trg_base_prices_write_history() OWNER TO app_owner;
ALTER FUNCTION application.trg_listing_availability_days_write_history() OWNER TO app_owner;
ALTER FUNCTION application.trg_listing_availability_days_prevent_delete() OWNER TO app_owner;
ALTER FUNCTION application.trg_bookings_validate_status_transition() OWNER TO app_owner;
ALTER FUNCTION application.trg_listing_availability_days_block_status_change_on_active_hold() OWNER TO app_owner;
ALTER FUNCTION application.trg_booking_days_prevent_active_overlap() OWNER TO app_owner;
ALTER FUNCTION application.trg_payments_require_not_expired_booking() OWNER TO app_owner;
ALTER FUNCTION application.trg_reviews_require_completed_booking() OWNER TO app_owner;
