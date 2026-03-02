-- V002: Create reference entities for RBAC and user status.
-- This migration contains stable dictionaries and enum types used by other tables.

-- Account status lifecycle for platform users.
CREATE TYPE user_status AS ENUM ('active', 'blocked', 'pending', 'deleted');

-- System roles. A user can have multiple roles through user_roles.
CREATE TABLE roles (
    id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(32) UNIQUE NOT NULL
);

INSERT INTO roles (name)
VALUES
    ('guest'),
    ('owner'),
    ('admin');

-- Atomic permissions in resource.action format.
CREATE TABLE permissions (
    id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(128) UNIQUE NOT NULL
);

INSERT INTO permissions (name)
VALUES
    ('listing.read'),
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