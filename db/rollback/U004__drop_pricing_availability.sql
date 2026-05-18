SET search_path = application, public;

DROP TRIGGER IF EXISTS trg_listing_availability_days_prevent_delete ON listing_availability_days;
DROP TRIGGER IF EXISTS trg_listing_availability_days_write_history ON listing_availability_days;
DROP TRIGGER IF EXISTS trg_base_prices_write_history ON base_prices;

DROP FUNCTION IF EXISTS trg_listing_availability_days_prevent_delete();
DROP FUNCTION IF EXISTS trg_listing_availability_days_write_history();
DROP FUNCTION IF EXISTS trg_base_prices_write_history();

DROP TABLE IF EXISTS price_history CASCADE;
DROP TABLE IF EXISTS listing_availability_days CASCADE;
DROP TABLE IF EXISTS base_prices CASCADE;
