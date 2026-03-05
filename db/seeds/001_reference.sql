-- 001_reference.sql
-- Базовые справочники для предметной области.
-- Этот сид можно запускать многократно: все вставки идемпотентны.

BEGIN;

-- 1) Типы объектов недвижимости.
INSERT INTO object_types (name)
VALUES ('apartment'),
       ('house'),
       ('studio'),
       ('loft'),
       ('villa'),
       ('townhouse'),
       ('cabin'),
       ('guesthouse')
ON CONFLICT (name) DO NOTHING;

-- 2) Страны (ISO 3166-1 alpha-2).
INSERT INTO countries (code, name)
VALUES ('US', 'United States'),
       ('DE', 'Germany'),
       ('RU', 'Russia'),
       ('FR', 'France'),
       ('GB', 'United Kingdom'),
       ('ES', 'Spain'),
       ('IT', 'Italy'),
       ('JP', 'Japan'),
       ('AE', 'United Arab Emirates'),
       ('TR', 'Turkey'),
       ('BR', 'Brazil'),
       ('CN', 'China')
ON CONFLICT (code) DO NOTHING;

-- 3) Города в разрезе стран.
INSERT INTO cities (country_id, name)
SELECT c.id, v.city_name
FROM (VALUES ('US', 'New York'),
             ('US', 'San Francisco'),
             ('US', 'Miami'),
             ('DE', 'Berlin'),
             ('DE', 'Munich'),
             ('RU', 'Moscow'),
             ('RU', 'Saint Petersburg'),
             ('FR', 'Paris'),
             ('FR', 'Lyon'),
             ('GB', 'London'),
             ('GB', 'Manchester'),
             ('ES', 'Barcelona'),
             ('IT', 'Rome'),
             ('JP', 'Tokyo'),
             ('JP', 'Osaka'),
             ('AE', 'Dubai'),
             ('AE', 'Abu Dhabi'),
             ('TR', 'Istanbul'),
             ('BR', 'Rio de Janeiro'),
             ('CN', 'Shanghai')) AS v(country_code, city_name)
         JOIN countries c ON c.code = v.country_code
ON CONFLICT ON CONSTRAINT uq_cities_country_name DO NOTHING;

-- 4) Валюты (ISO 4217).
INSERT INTO currencies (code, numeric_code, name, symbol, minor_unit, is_active)
VALUES ('USD', '840', 'US Dollar', '$', 2, true),
       ('EUR', '978', 'Euro', '€', 2, true),
       ('RUB', '643', 'Russian Ruble', '₽', 2, true),
       ('GBP', '826', 'Pound Sterling', '£', 2, true),
       ('JPY', '392', 'Japanese Yen', '¥', 0, true),
       ('AED', '784', 'UAE Dirham', 'د.إ', 2, true),
       ('TRY', '949', 'Turkish Lira', '₺', 2, true),
       ('BRL', '986', 'Brazilian Real', 'R$', 2, true),
       ('CNY', '156', 'Chinese Yuan', '¥', 2, true)
ON CONFLICT (code) DO NOTHING;

COMMIT;
