-- U002: откат справочников и enum-типов из V002.

-- Таблицы.
DROP TABLE IF EXISTS addresses;
DROP TABLE IF EXISTS cities;
DROP TABLE IF EXISTS countries;
DROP TABLE IF EXISTS object_types;
DROP TABLE IF EXISTS permissions;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS currencies;

-- Типы.
DROP TYPE IF EXISTS price_change_source;
DROP TYPE IF EXISTS availability_status;
DROP TYPE IF EXISTS photo_extension;
DROP TYPE IF EXISTS listing_publication_status;
DROP TYPE IF EXISTS user_status;
