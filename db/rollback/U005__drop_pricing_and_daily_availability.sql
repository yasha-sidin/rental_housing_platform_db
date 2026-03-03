-- U005: откат ценообразования и дневной доступности из V005.

DROP TRIGGER IF EXISTS trg_listing_availability_days_prevent_delete ON listing_availability_days;
DROP FUNCTION IF EXISTS trg_listing_availability_days_prevent_delete();

DROP TRIGGER IF EXISTS trg_listing_availability_days_write_history ON listing_availability_days;
DROP FUNCTION IF EXISTS trg_listing_availability_days_write_history();

DROP TRIGGER IF EXISTS trg_base_prices_write_history ON base_prices;
DROP FUNCTION IF EXISTS trg_base_prices_write_history();

DROP TABLE IF EXISTS price_history;
DROP TABLE IF EXISTS listing_availability_days;
DROP TABLE IF EXISTS base_prices;
