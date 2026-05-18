SET search_path = application, public;

BEGIN;

INSERT INTO object_types (name)
VALUES ('apartment'),
       ('house'),
       ('studio'),
       ('loft'),
       ('villa'),
       ('townhouse')
ON CONFLICT (name) DO NOTHING;

INSERT INTO countries (code, name)
VALUES ('US', 'United States'),
       ('DE', 'Germany'),
       ('RU', 'Russia'),
       ('FR', 'France'),
       ('GB', 'United Kingdom'),
       ('ES', 'Spain'),
       ('IT', 'Italy')
ON CONFLICT (code) DO NOTHING;

INSERT INTO cities (country_id, name)
SELECT c.id, v.city_name
FROM (VALUES ('US', 'New York'),
             ('US', 'San Francisco'),
             ('DE', 'Berlin'),
             ('RU', 'Moscow'),
             ('FR', 'Paris'),
             ('GB', 'London'),
             ('ES', 'Barcelona'),
             ('IT', 'Rome')) AS v(country_code, city_name)
         JOIN countries c ON c.code = v.country_code
ON CONFLICT ON CONSTRAINT uq_cities_country_name DO NOTHING;

INSERT INTO currencies (code, numeric_code, name, symbol, minor_unit, is_active)
VALUES ('USD', '840', 'US Dollar', '$', 2, true),
       ('EUR', '978', 'Euro', 'EUR', 2, true),
       ('RUB', '643', 'Russian Ruble', 'RUB', 2, true),
       ('GBP', '826', 'Pound Sterling', 'GBP', 2, true)
ON CONFLICT (code) DO NOTHING;

COMMIT;
