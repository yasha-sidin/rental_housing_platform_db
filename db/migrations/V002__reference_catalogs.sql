SET search_path = application, public;

CREATE TYPE user_status AS ENUM ('active', 'blocked', 'pending', 'deleted');
CREATE TYPE listing_publication_status AS ENUM ('active', 'hidden', 'blocked');
CREATE TYPE photo_extension AS ENUM ('png', 'jpeg');
CREATE TYPE availability_status AS ENUM ('available', 'held', 'booked', 'blocked');
CREATE TYPE price_change_source AS ENUM ('base_price', 'day_override');

CREATE TABLE roles
(
    id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(32) UNIQUE NOT NULL
);

CREATE TABLE permissions
(
    id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(128) UNIQUE NOT NULL
);

CREATE TABLE role_permissions
(
    role_id       BIGINT NOT NULL REFERENCES roles (id),
    permission_id BIGINT NOT NULL REFERENCES permissions (id),
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE object_types
(
    id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(128) UNIQUE NOT NULL,
    CONSTRAINT chk_object_types_name_not_blank CHECK (btrim(name) <> '')
);

CREATE TABLE countries
(
    id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code CHAR(2) UNIQUE NOT NULL,
    name VARCHAR(128) NOT NULL UNIQUE,
    CONSTRAINT chk_countries_code_iso_alpha2 CHECK (code ~ '^[A-Z]{2}$'),
    CONSTRAINT chk_countries_name_not_blank CHECK (btrim(name) <> '')
);

CREATE TABLE cities
(
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_id BIGINT       NOT NULL REFERENCES countries (id),
    name       VARCHAR(128) NOT NULL,
    CONSTRAINT uq_cities_country_name UNIQUE (country_id, name),
    CONSTRAINT chk_city_name_not_blank CHECK (btrim(name) <> '')
);

CREATE TABLE addresses
(
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city_id      BIGINT       NOT NULL REFERENCES cities (id),
    street_line1 VARCHAR(256) NOT NULL,
    street_line2 VARCHAR(256),
    region       VARCHAR(128),
    postal_code  VARCHAR(32),
    link         VARCHAR(512),
    CONSTRAINT chk_street_line1_not_blank CHECK (btrim(street_line1) <> '')
);

CREATE TABLE currencies
(
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code             VARCHAR(3) UNIQUE   NOT NULL,
    numeric_code     VARCHAR(3) UNIQUE,
    name             VARCHAR(128) UNIQUE NOT NULL,
    symbol           VARCHAR(8),
    minor_unit       SMALLINT            NOT NULL DEFAULT 2,
    is_active        BOOLEAN             NOT NULL DEFAULT true,
    creation_date    TIMESTAMPTZ         NOT NULL DEFAULT now(),
    last_update_date TIMESTAMPTZ         NOT NULL DEFAULT now(),
    CONSTRAINT chk_currencies_code_iso4217 CHECK (code ~ '^[A-Z]{3}$'),
    CONSTRAINT chk_currencies_numeric_code CHECK (numeric_code IS NULL OR numeric_code ~ '^[0-9]{3}$'),
    CONSTRAINT chk_currencies_name_not_blank CHECK (btrim(name) <> ''),
    CONSTRAINT chk_currencies_minor_unit_range CHECK (minor_unit BETWEEN 0 AND 6),
    CONSTRAINT chk_currencies_update_not_before_create CHECK (last_update_date >= creation_date)
);

INSERT INTO roles (name)
VALUES ('guest'), ('owner'), ('admin');

INSERT INTO permissions (name)
VALUES ('listing.read'), ('listing.create'), ('listing.update'),
       ('photo.read'), ('photo.create'), ('photo.delete'),
       ('booking.create'), ('booking.read'), ('booking.update'), ('booking.cancel'),
       ('payment.create'), ('payment.read'), ('payment.refund'),
       ('review.create'), ('review.read'), ('review.moderate'), ('review.delete'),
       ('availability.create'), ('availability.update'),
       ('price_rule.create'), ('price_rule.update'), ('price_rule.delete'),
       ('report.read'), ('user.read'), ('user.update');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM (VALUES
          ('guest', 'listing.read'), ('guest', 'photo.read'), ('guest', 'booking.create'),
          ('guest', 'booking.read'), ('guest', 'booking.cancel'), ('guest', 'payment.create'),
          ('guest', 'payment.read'), ('guest', 'review.create'), ('guest', 'review.read'),
          ('owner', 'listing.create'), ('owner', 'listing.read'), ('owner', 'listing.update'),
          ('owner', 'photo.create'), ('owner', 'photo.read'), ('owner', 'photo.delete'),
          ('owner', 'availability.create'), ('owner', 'availability.update'),
          ('owner', 'price_rule.create'), ('owner', 'price_rule.update'), ('owner', 'price_rule.delete'),
          ('owner', 'booking.read'), ('owner', 'booking.update'), ('owner', 'booking.cancel'),
          ('owner', 'report.read'),
          ('admin', 'user.read'), ('admin', 'user.update'), ('admin', 'listing.read'),
          ('admin', 'listing.update'), ('admin', 'photo.read'), ('admin', 'photo.delete'),
          ('admin', 'booking.read'), ('admin', 'booking.update'), ('admin', 'booking.cancel'),
          ('admin', 'payment.read'), ('admin', 'payment.refund'), ('admin', 'review.read'),
          ('admin', 'review.moderate'), ('admin', 'review.delete'), ('admin', 'report.read')) AS x(role_name, permission_name)
         JOIN roles r ON r.name = x.role_name
         JOIN permissions p ON p.name = x.permission_name;
