-- update_from.sql
-- Домашнее задание: DML в PostgreSQL.
--
-- Условие:
-- Написать запрос с обновлением данных, используя UPDATE FROM.
--
-- Выбранный сценарий:
-- Повысить дневные override-цены для активных объявлений в выбранном городе на
-- ближайшие выходные. UPDATE FROM здесь уместен, потому что обновляемая таблица
-- `listing_availability_days` должна быть связана с объявлениями, адресами,
-- городами, базовыми ценами и валютами.
--
-- Реализация:

SET search_path = application, public;

BEGIN;

WITH nearest_weekend AS (
    SELECT current_date +
           ((6 - EXTRACT(ISODOW FROM current_date)::int + 7) % 7) AS saturday_date
)
UPDATE listing_availability_days AS day
SET
    override_in_minor = base_prices.amount_in_minor + 3000,
    override_currency_id = base_prices.currency_id,
    last_update_date = now()
FROM listings
    INNER JOIN base_prices ON base_prices.listing_id = listings.id
    INNER JOIN addresses ON addresses.id = listings.address_id
    INNER JOIN (
        SELECT id, name FROM cities WHERE name = 'San Francisco'
    ) AS selected_city ON selected_city.id = addresses.city_id
    CROSS JOIN nearest_weekend
WHERE day.listing_id = listings.id
    AND listings.status = 'active'
    AND day.status = 'available'
    AND day.available_date IN (
        nearest_weekend.saturday_date,
        nearest_weekend.saturday_date + 1
    )
RETURNING
    day.id AS availability_day_id,
    listings.id AS listing_id,
    selected_city.name AS city_name,
    day.available_date,
    base_prices.amount_in_minor AS base_price_in_minor,
    day.override_in_minor,
    day.override_currency_id,
    day.last_update_date;

ROLLBACK;
