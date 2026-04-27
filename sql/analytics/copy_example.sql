-- copy_example.sql
-- Домашнее задание: DML в PostgreSQL.
--
-- Условие со звездочкой:
-- Привести пример использования утилиты COPY.
--
-- Выбранный сценарий:
-- Экспортировать аналитическую витрину по активным объявлениям: владелец,
-- страна, город, описание объекта, вместимость, базовая цена и валюта.
-- Такой результат удобно выгружать в CSV для отчета или передачи аналитикам.
--
-- Реализация:

SET search_path = application, public;

COPY (
    SELECT
        listing.id AS listing_id,
        owner.username AS owner_username,
        country.name AS country_name,
        city.name AS city_name,
        object_type.name AS object_type_name,
        listing.description,
        listing.capacity,
        listing.number_of_rooms,
        base_price.amount_in_minor AS base_price_in_minor,
        currency.code AS currency_code
    FROM listings AS listing
             INNER JOIN users AS owner
                        ON owner.id = listing.owner_id
             INNER JOIN object_types AS object_type
                        ON object_type.id = listing.object_type_id
             INNER JOIN addresses AS address
                        ON address.id = listing.address_id
             INNER JOIN cities AS city
                        ON city.id = address.city_id
             INNER JOIN countries AS country
                        ON country.id = city.country_id
             INNER JOIN base_prices AS base_price
                        ON base_price.listing_id = listing.id
             INNER JOIN currencies AS currency
                        ON currency.id = base_price.currency_id
    WHERE listing.status = 'active'
    ORDER BY country.name, city.name, listing.id
    LIMIT 1000
) TO '/workspace/artifacts/snapshots/dml/active_listings_report.csv'
WITH (FORMAT csv, HEADER true);
