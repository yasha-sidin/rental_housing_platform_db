-- V002: справочники и enum-типы, которые используются в других таблицах.

-- Статусы учетной записи пользователя.
CREATE TYPE user_status AS ENUM ('active', 'blocked', 'pending', 'deleted');

-- Системные роли RBAC. Один пользователь может иметь несколько ролей через user_roles.
CREATE TABLE roles
(
    id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(32) UNIQUE NOT NULL
);

INSERT INTO roles (name)
VALUES ('guest'),
       ('owner'),
       ('admin');

-- Атомарные разрешения RBAC в формате resource.action.
CREATE TABLE permissions
(
    id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(128) UNIQUE NOT NULL
);

INSERT INTO permissions (name)
VALUES ('listing.read'),
       ('listing.create'),
       ('listing.update'),

       ('photo.read'),
       ('photo.create'),
       ('photo.delete'),

       ('booking.create'),
       ('booking.read'),
       ('booking.update'),
       ('booking.cancel'),

       ('payment.create'),
       ('payment.read'),
       ('payment.refund'),

       ('review.create'),
       ('review.read'),
       ('review.moderate'),
       ('review.delete'),

       ('availability.create'),
       ('availability.update'),

       ('price_rule.create'),
       ('price_rule.update'),
       ('price_rule.delete'),

       ('report.read'),

       ('user.read'),
       ('user.update');

-- Типы объектов недвижимости (квартира, дом, студия и т.д.).
CREATE TABLE object_types
(
    id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(128) UNIQUE NOT NULL,
    -- Проверка запрещает пустое или состоящее только из пробелов имя типа объекта.
    CONSTRAINT chk_object_types_name_not_blank CHECK (btrim(name) <> '')
);

-- Страны в формате ISO 3166-1 alpha-2.
CREATE TABLE countries
(
    id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code CHAR(2) UNIQUE NOT NULL,
    name VARCHAR(128)   NOT NULL UNIQUE,
    -- Проверка гарантирует двухсимвольный код страны в верхнем регистре (например, US, DE).
    CONSTRAINT chk_countries_code_iso_alpha2 CHECK (code ~ '^[A-Z]{2}$'),
    -- Проверка запрещает пустое имя страны.
    CONSTRAINT chk_countries_name_not_blank CHECK (btrim(name) <> '')
);

-- Города. Одно и то же название города может повторяться в разных странах.
CREATE TABLE cities
(
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_id BIGINT       NOT NULL REFERENCES countries (id),
    name       VARCHAR(128) NOT NULL,
    CONSTRAINT uq_cities_country_name UNIQUE (country_id, name),
    -- Проверка запрещает пустое имя города.
    CONSTRAINT chk_city_name_not_blank CHECK (btrim(name) <> '')
);

-- Нормализованный адрес объекта недвижимости.
CREATE TABLE addresses
(
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city_id      BIGINT       NOT NULL REFERENCES cities (id),
    street_line1 VARCHAR(256) NOT NULL,
    street_line2 VARCHAR(256),
    region       VARCHAR(128),
    postal_code  VARCHAR(32),
    link         VARCHAR(512),
    -- Проверка запрещает пустую основную строку адреса.
    CONSTRAINT chk_street_line1_not_blank CHECK (btrim(street_line1) <> '')
);

-- Статус публикации объявления/объекта.
CREATE TYPE listing_publication_status AS ENUM ('active', 'hidden', 'blocked');

-- Допустимые расширения файлов изображений.
CREATE TYPE photo_extension AS ENUM ('png', 'jpeg');

-- Справочник валют.
CREATE TABLE currencies
(
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- Используем VARCHAR(3), а не CHAR(3), чтобы избежать сравнения со служебными пробелами.
    code             VARCHAR(3) UNIQUE   NOT NULL,
    -- Числовой ISO-код валюты (например, 840 для USD). Храним строкой, чтобы сохранять ведущие нули.
    numeric_code     VARCHAR(3) UNIQUE,
    name             VARCHAR(128) UNIQUE NOT NULL,
    symbol           VARCHAR(8),
    -- Minor unit определяет количество знаков после запятой в стандартном представлении валюты.
    minor_unit       SMALLINT            NOT NULL DEFAULT 2,
    is_active        BOOLEAN             NOT NULL DEFAULT true,
    creation_date    TIMESTAMPTZ         NOT NULL DEFAULT now(),
    last_update_date TIMESTAMPTZ         NOT NULL DEFAULT now(),
    -- Проверка обеспечивает формат кода ISO 4217: три буквы в верхнем регистре.
    CONSTRAINT chk_currencies_code_iso4217
        CHECK (code ~ '^[A-Z]{3}$'),
    -- Проверка обеспечивает формат числового ISO-кода: три цифры.
    CONSTRAINT chk_currencies_numeric_code
        CHECK (numeric_code IS NULL OR numeric_code ~ '^[0-9]{3}$'),
    -- Проверка запрещает пустое имя валюты.
    CONSTRAINT chk_currencies_name_not_blank
        CHECK (btrim(name) <> ''),
    -- Проверка ограничивает диапазон minor unit реалистичными значениями.
    CONSTRAINT chk_currencies_minor_unit_range
        CHECK (minor_unit BETWEEN 0 AND 6),
    -- Проверка защищает временную целостность записи.
    CONSTRAINT chk_currencies_update_not_before_create
        CHECK (last_update_date >= creation_date)
);

-- Статус доступности конкретного дня.
CREATE TYPE availability_status AS ENUM ('available', 'held', 'booked', 'blocked');

-- Источник изменения цены.
CREATE TYPE price_change_source AS ENUM ('base_price', 'day_override');
