SET search_path = application, public;

DROP TRIGGER IF EXISTS trg_listings_prevent_delete ON listings;
DROP FUNCTION IF EXISTS trg_listings_prevent_delete();

DROP TABLE IF EXISTS listing_photos CASCADE;
DROP TABLE IF EXISTS photos CASCADE;
DROP TABLE IF EXISTS listings CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;
DROP TABLE IF EXISTS users CASCADE;
