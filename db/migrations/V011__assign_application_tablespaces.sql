-- V011: распределение объектов application по табличным пространствам.
--
-- Tablespace - это физическое место хранения файлов PostgreSQL на сервере.
-- В docker-compose каждый tablespace смонтирован отдельным named volume. В локальной
-- среде это моделирует разные физические диски; в production эти mount points можно
-- направить на разные устройства или классы storage.
--
-- Эта миграция не создает tablespaces. Они создаются заранее bootstrap-скриптом:
--   db/bootstrap/001__create_tablespaces.sql
--
-- Почему так:
-- - CREATE TABLESPACE работает на уровне PostgreSQL-кластера, а не схемы application.
-- - Для CREATE TABLESPACE нужен существующий server-side путь.
-- - CREATE TABLESPACE нельзя выполнять внутри transaction block.
--
-- Здесь мы только проверяем, что нужные tablespaces уже есть, назначаем владельца
-- app_owner и переносим существующие таблицы и индексы.

-- ---------------------------------------------------------------------------
-- 1) Проверяем, что bootstrap уже создал все нужные tablespaces.
-- ---------------------------------------------------------------------------
DO
$$
DECLARE
    v_missing_tablespaces TEXT;
BEGIN
    SELECT string_agg(required.spcname, ', ' ORDER BY required.spcname)
    INTO v_missing_tablespaces
    FROM (VALUES
              ('rental_reference_ts'),
              ('rental_core_ts'),
              ('rental_booking_ts'),
              ('rental_history_ts'),
              ('rental_index_ts')
         ) AS required(spcname)
    WHERE NOT EXISTS (
        SELECT 1
        FROM pg_tablespace existing
        WHERE existing.spcname = required.spcname
    );

    IF v_missing_tablespaces IS NOT NULL THEN
        RAISE EXCEPTION
            'Required tablespaces are missing: %. Run make bootstrap-tablespaces before migrations.',
            v_missing_tablespaces;
    END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- 2) Передаем ownership tablespaces роли app_owner.
--
-- app_owner уже создан в V010 и является владельцем application-объектов.
-- Владение tablespaces позволяет этой роли создавать/перемещать объекты в эти
-- физические области хранения.
-- ---------------------------------------------------------------------------
ALTER TABLESPACE rental_reference_ts OWNER TO app_owner;
ALTER TABLESPACE rental_core_ts OWNER TO app_owner;
ALTER TABLESPACE rental_booking_ts OWNER TO app_owner;
ALTER TABLESPACE rental_history_ts OWNER TO app_owner;
ALTER TABLESPACE rental_index_ts OWNER TO app_owner;

-- ---------------------------------------------------------------------------
-- 3) Справочники и RBAC -> rental_reference_ts.
--
-- Это небольшие, относительно стабильные таблицы: роли, разрешения, справочники
-- стран/городов/валют и типы объектов недвижимости.
-- ---------------------------------------------------------------------------
ALTER TABLE application.roles SET TABLESPACE rental_reference_ts;
ALTER TABLE application.permissions SET TABLESPACE rental_reference_ts;
ALTER TABLE application.role_permissions SET TABLESPACE rental_reference_ts;
ALTER TABLE application.object_types SET TABLESPACE rental_reference_ts;
ALTER TABLE application.countries SET TABLESPACE rental_reference_ts;
ALTER TABLE application.cities SET TABLESPACE rental_reference_ts;
ALTER TABLE application.currencies SET TABLESPACE rental_reference_ts;

-- ---------------------------------------------------------------------------
-- 4) Основные сущности каталога -> rental_core_ts.
--
-- Здесь лежат пользователи, назначения ролей пользователям, адреса, объявления,
-- фотографии и базовые цены.
-- ---------------------------------------------------------------------------
ALTER TABLE application.users SET TABLESPACE rental_core_ts;
ALTER TABLE application.user_roles SET TABLESPACE rental_core_ts;
ALTER TABLE application.addresses SET TABLESPACE rental_core_ts;
ALTER TABLE application.listings SET TABLESPACE rental_core_ts;
ALTER TABLE application.photos SET TABLESPACE rental_core_ts;
ALTER TABLE application.listing_photos SET TABLESPACE rental_core_ts;
ALTER TABLE application.base_prices SET TABLESPACE rental_core_ts;

-- ---------------------------------------------------------------------------
-- 5) Транзакционная нагрузка бронирований -> rental_booking_ts.
--
-- Эти таблицы чаще меняются: календарь доступности, бронирования, выбранные дни и
-- платежные сессии.
-- ---------------------------------------------------------------------------
ALTER TABLE application.listing_availability_days SET TABLESPACE rental_booking_ts;
ALTER TABLE application.bookings SET TABLESPACE rental_booking_ts;
ALTER TABLE application.booking_days SET TABLESPACE rental_booking_ts;
ALTER TABLE application.payments SET TABLESPACE rental_booking_ts;

-- ---------------------------------------------------------------------------
-- 6) История и аналитически полезные данные -> rental_history_ts.
--
-- price_history хранит аудит изменения цен, reviews - отзывы и модерацию.
-- Это логически отдельная область, которая может расти иначе, чем core-таблицы.
-- ---------------------------------------------------------------------------
ALTER TABLE application.price_history SET TABLESPACE rental_history_ts;
ALTER TABLE application.reviews SET TABLESPACE rental_history_ts;

-- ---------------------------------------------------------------------------
-- 7) Все индексы application -> rental_index_ts.
--
-- ALTER TABLE ... SET TABLESPACE не переносит индексы таблицы, поэтому индексы
-- перемещаются отдельно. Динамический блок покрывает как обычные индексы из V009,
-- так и индексы, созданные constraints (PRIMARY KEY, UNIQUE).
-- ---------------------------------------------------------------------------
DO
$$
DECLARE
    v_index RECORD;
BEGIN
    FOR v_index IN
        SELECT n.nspname AS schema_name,
               c.relname AS index_name
        FROM pg_class c
                 JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'application'
          AND c.relkind = 'i'
        ORDER BY c.relname
    LOOP
        EXECUTE format(
            'ALTER INDEX %I.%I SET TABLESPACE rental_index_ts',
            v_index.schema_name,
            v_index.index_name
        );
    END LOOP;
END;
$$;
