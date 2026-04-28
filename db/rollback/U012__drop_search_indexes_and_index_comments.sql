-- U012: откат индексов и объектных комментариев из V012.

DROP INDEX IF EXISTS application.idx_listings_description_fts;
DROP INDEX IF EXISTS application.idx_listings_active_capacity_rooms;

DO
$$
DECLARE
    v_index_name TEXT;
BEGIN
    FOREACH v_index_name IN ARRAY ARRAY[
        'idx_countries_name_lower',
        'idx_cities_name_lower',
        'idx_addresses_city_id',
        'idx_addresses_street_line1_trgm',
        'idx_addresses_city_id_postal_code',
        'idx_currencies_is_active_true',
        'idx_users_status',
        'idx_role_permissions_permission_id',
        'idx_user_roles_role_id',
        'idx_listings_owner_id',
        'idx_listings_object_type_id',
        'idx_listings_address_id',
        'idx_listings_status',
        'idx_price_history_listing_id',
        'idx_bookings_listing_id',
        'idx_bookings_created_by_user_creation_date_desc',
        'idx_bookings_status',
        'idx_availability_day_id_listing_id_booking_id',
        'idx_payments_status_session_expires_at',
        'idx_reviews_unmoderated_creation_date'
    ]
    LOOP
        IF to_regclass('application.' || v_index_name) IS NOT NULL THEN
            EXECUTE format('COMMENT ON INDEX application.%I IS NULL', v_index_name);
        END IF;
    END LOOP;
END;
$$;
