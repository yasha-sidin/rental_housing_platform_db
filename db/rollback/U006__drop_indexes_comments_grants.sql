SET search_path = application, public;

DROP INDEX IF EXISTS idx_reviews_unmoderated_creation_date;
DROP INDEX IF EXISTS idx_payments_status_session_expires_at;
DROP INDEX IF EXISTS idx_availability_day_id_listing_id_booking_id;
DROP INDEX IF EXISTS idx_bookings_status;
DROP INDEX IF EXISTS idx_bookings_created_by_user_creation_date_desc;
DROP INDEX IF EXISTS idx_bookings_listing_id;
DROP INDEX IF EXISTS idx_price_history_listing_id;
DROP INDEX IF EXISTS idx_listings_active_capacity_rooms;
DROP INDEX IF EXISTS idx_listings_description_fts;
DROP INDEX IF EXISTS idx_listings_status;
DROP INDEX IF EXISTS idx_listings_address_id;
DROP INDEX IF EXISTS idx_listings_object_type_id;
DROP INDEX IF EXISTS idx_listings_owner_id;
DROP INDEX IF EXISTS idx_user_roles_role_id;
DROP INDEX IF EXISTS idx_role_permissions_permission_id;
DROP INDEX IF EXISTS idx_users_status;
DROP INDEX IF EXISTS idx_currencies_is_active_true;
DROP INDEX IF EXISTS idx_addresses_city_id_postal_code;
DROP INDEX IF EXISTS idx_addresses_street_line1_trgm;
DROP INDEX IF EXISTS idx_addresses_city_id;
DROP INDEX IF EXISTS idx_cities_name_lower;
DROP INDEX IF EXISTS idx_countries_name_lower;

COMMENT ON SCHEMA application IS NULL;
