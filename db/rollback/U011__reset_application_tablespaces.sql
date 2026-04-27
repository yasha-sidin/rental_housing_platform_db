-- U011: откат V011.
--
-- Возвращает таблицы и индексы application в стандартное табличное пространство
-- pg_default.
--
-- Tablespaces не удаляются: это cluster-level объекты, которые могут использоваться
-- другими базами. Их создание/удаление относится к bootstrap/инфраструктурному слою,
-- а не к rollback прикладной схемы.

-- ---------------------------------------------------------------------------
-- 1) Возвращаем все индексы application в pg_default.
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
            'ALTER INDEX %I.%I SET TABLESPACE pg_default',
            v_index.schema_name,
            v_index.index_name
        );
    END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- 2) Возвращаем таблицы в pg_default.
-- ---------------------------------------------------------------------------
ALTER TABLE application.roles SET TABLESPACE pg_default;
ALTER TABLE application.permissions SET TABLESPACE pg_default;
ALTER TABLE application.role_permissions SET TABLESPACE pg_default;
ALTER TABLE application.object_types SET TABLESPACE pg_default;
ALTER TABLE application.countries SET TABLESPACE pg_default;
ALTER TABLE application.cities SET TABLESPACE pg_default;
ALTER TABLE application.currencies SET TABLESPACE pg_default;

ALTER TABLE application.users SET TABLESPACE pg_default;
ALTER TABLE application.user_roles SET TABLESPACE pg_default;
ALTER TABLE application.addresses SET TABLESPACE pg_default;
ALTER TABLE application.listings SET TABLESPACE pg_default;
ALTER TABLE application.photos SET TABLESPACE pg_default;
ALTER TABLE application.listing_photos SET TABLESPACE pg_default;
ALTER TABLE application.base_prices SET TABLESPACE pg_default;

ALTER TABLE application.listing_availability_days SET TABLESPACE pg_default;
ALTER TABLE application.bookings SET TABLESPACE pg_default;
ALTER TABLE application.booking_days SET TABLESPACE pg_default;
ALTER TABLE application.payments SET TABLESPACE pg_default;

ALTER TABLE application.price_history SET TABLESPACE pg_default;
ALTER TABLE application.reviews SET TABLESPACE pg_default;

-- ---------------------------------------------------------------------------
-- 3) Возвращаем ownership tablespaces на CURRENT_USER.
--
-- V011 передавала ownership роли app_owner. Если откатываемся ниже V011, это
-- владение больше не должно мешать последующему откату V010 и удалению app_owner.
-- ---------------------------------------------------------------------------
ALTER TABLESPACE rental_reference_ts OWNER TO CURRENT_USER;
ALTER TABLESPACE rental_core_ts OWNER TO CURRENT_USER;
ALTER TABLESPACE rental_booking_ts OWNER TO CURRENT_USER;
ALTER TABLESPACE rental_history_ts OWNER TO CURRENT_USER;
ALTER TABLESPACE rental_index_ts OWNER TO CURRENT_USER;
