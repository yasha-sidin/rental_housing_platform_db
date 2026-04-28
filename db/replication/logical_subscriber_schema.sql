\set ON_ERROR_STOP on

CREATE SCHEMA IF NOT EXISTS application;

CREATE TABLE IF NOT EXISTS application.currencies
(
    id               BIGINT PRIMARY KEY,
    code             VARCHAR(3) UNIQUE   NOT NULL,
    numeric_code     VARCHAR(3) UNIQUE,
    name             VARCHAR(128) UNIQUE NOT NULL,
    symbol           VARCHAR(8),
    minor_unit       SMALLINT            NOT NULL DEFAULT 2,
    is_active        BOOLEAN             NOT NULL DEFAULT true,
    creation_date    TIMESTAMPTZ         NOT NULL,
    last_update_date TIMESTAMPTZ         NOT NULL
);
