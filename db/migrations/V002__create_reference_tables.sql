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
       ('listing.delete'),

       ('booking.create'),
       ('booking.read'),
       ('booking.update'),
       ('booking.cancel'),

       ('payment.create'),
       ('payment.read'),

       ('review.create'),
       ('review.read'),
       ('review.moderate'),
       ('review.delete'),

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
