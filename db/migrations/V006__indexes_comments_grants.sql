SET search_path = application, public;

CREATE INDEX idx_countries_name_lower ON countries (lower(name));
CREATE INDEX idx_cities_name_lower ON cities (lower(name));
CREATE INDEX idx_addresses_city_id ON addresses (city_id);
CREATE INDEX idx_addresses_street_line1_trgm ON addresses USING GIN ((coalesce(street_line1, '')) gin_trgm_ops);
CREATE INDEX idx_addresses_city_id_postal_code ON addresses (city_id, lower(postal_code));
CREATE INDEX idx_currencies_is_active_true ON currencies (id) WHERE is_active = true;
CREATE INDEX idx_users_status ON users (status);
CREATE INDEX idx_role_permissions_permission_id ON role_permissions (permission_id);
CREATE INDEX idx_user_roles_role_id ON user_roles (role_id);
CREATE INDEX idx_listings_owner_id ON listings (owner_id);
CREATE INDEX idx_listings_object_type_id ON listings (object_type_id);
CREATE INDEX idx_listings_address_id ON listings (address_id);
CREATE INDEX idx_listings_status ON listings (status);
CREATE INDEX idx_listings_description_fts ON listings USING GIN (to_tsvector('simple', coalesce(description, '')));
CREATE INDEX idx_listings_active_capacity_rooms ON listings (capacity, number_of_rooms) WHERE status = 'active';
CREATE INDEX idx_price_history_listing_id ON price_history (listing_id);
CREATE INDEX idx_bookings_listing_id ON bookings (listing_id);
CREATE INDEX idx_bookings_created_by_user_creation_date_desc ON bookings (created_by_user_id, creation_date DESC);
CREATE INDEX idx_bookings_status ON bookings (status);
CREATE INDEX idx_availability_day_id_listing_id_booking_id ON booking_days (availability_day_id, listing_id, booking_id);
CREATE INDEX idx_payments_status_session_expires_at ON payments (status, provider_payment_session_expires_at);
CREATE INDEX idx_reviews_unmoderated_creation_date ON reviews (creation_date) WHERE moderated = false;

COMMENT ON SCHEMA application IS 'Прикладная схема платформы краткосрочной аренды жилья.';
COMMENT ON TABLE users IS 'Пользователи платформы: гости, владельцы и администраторы.';
COMMENT ON TABLE listings IS 'Объявления краткосрочной аренды жилья.';
COMMENT ON TABLE listing_availability_days IS 'Календарь доступности объявлений по дням.';
COMMENT ON TABLE bookings IS 'Бронирования жилья пользователями.';
COMMENT ON TABLE payments IS 'Платежные сессии и итоговые статусы оплат.';
COMMENT ON TABLE reviews IS 'Отзывы по завершенным бронированиям.';

GRANT SELECT ON ALL TABLES IN SCHEMA application TO app_readonly;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA application TO app_readwrite;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA application TO app_owner;

GRANT SELECT ON ALL SEQUENCES IN SCHEMA application TO app_readonly;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA application TO app_readwrite;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA application TO app_owner;

DO
$$
DECLARE
    enum_record RECORD;
BEGIN
    FOR enum_record IN
        SELECT format('%I.%I', n.nspname, t.typname) AS type_name
        FROM pg_type t
                 JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE n.nspname = 'application'
          AND t.typtype = 'e'
    LOOP
        EXECUTE 'GRANT USAGE ON TYPE ' || enum_record.type_name || ' TO app_readonly, app_readwrite, app_owner';
    END LOOP;
END;
$$;

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA application FROM PUBLIC;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA application TO app_owner;

ALTER DEFAULT PRIVILEGES IN SCHEMA application GRANT SELECT ON TABLES TO app_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA application GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_readwrite;
ALTER DEFAULT PRIVILEGES IN SCHEMA application GRANT SELECT ON SEQUENCES TO app_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA application GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO app_readwrite;
ALTER DEFAULT PRIVILEGES IN SCHEMA application GRANT USAGE ON TYPES TO app_readonly, app_readwrite, app_owner;
ALTER DEFAULT PRIVILEGES IN SCHEMA application GRANT ALL PRIVILEGES ON FUNCTIONS TO app_owner;

DO
$$
DECLARE
    object_record RECORD;
BEGIN
    FOR object_record IN
        SELECT format('%I.%I', schemaname, tablename) AS object_name
        FROM pg_tables
        WHERE schemaname = 'application'
    LOOP
        EXECUTE 'ALTER TABLE ' || object_record.object_name || ' OWNER TO app_owner';
    END LOOP;

    FOR object_record IN
        SELECT format('%I.%I', sequence_schema, sequence_name) AS object_name
        FROM information_schema.sequences
        WHERE sequence_schema = 'application'
    LOOP
        EXECUTE 'ALTER SEQUENCE ' || object_record.object_name || ' OWNER TO app_owner';
    END LOOP;

    FOR object_record IN
        SELECT format('%I.%I(%s)', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid)) AS object_name
        FROM pg_proc p
                 JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'application'
    LOOP
        EXECUTE 'ALTER FUNCTION ' || object_record.object_name || ' OWNER TO app_owner';
    END LOOP;
END;
$$;
