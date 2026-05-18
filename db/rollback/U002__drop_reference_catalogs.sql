SET search_path = application, public;

DROP TABLE IF EXISTS currencies CASCADE;
DROP TABLE IF EXISTS addresses CASCADE;
DROP TABLE IF EXISTS cities CASCADE;
DROP TABLE IF EXISTS countries CASCADE;
DROP TABLE IF EXISTS object_types CASCADE;
DROP TABLE IF EXISTS role_permissions CASCADE;
DROP TABLE IF EXISTS permissions CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

DROP TYPE IF EXISTS price_change_source;
DROP TYPE IF EXISTS availability_status;
DROP TYPE IF EXISTS photo_extension;
DROP TYPE IF EXISTS listing_publication_status;
DROP TYPE IF EXISTS user_status;
