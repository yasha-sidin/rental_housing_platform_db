-- 002_base_entities.sql
-- Базовые сущности: пользователи, роли, адреса, объявления, фото, цены, доступность.
-- Скрипт можно запускать повторно: ключевые вставки идемпотентны.

BEGIN;

-- ============================================================================
-- 1. Пользователи
-- ============================================================================
-- Добавляем разнообразный набор учетных записей:
-- - владельцы;
-- - гости;
-- - администраторы;
-- - комбинированный пользователь (owner + guest);
-- - аккаунты в разных статусах.
INSERT INTO users (username, phone_number, email, status)
VALUES ('seed_owner_1', '+10000000001', 'seed_owner_1@example.com', 'active'),
       ('seed_owner_2', '+10000000002', 'seed_owner_2@example.com', 'active'),
       ('seed_owner_3', '+10000000003', 'seed_owner_3@example.com', 'active'),
       ('seed_owner_4', '+10000000004', 'seed_owner_4@example.com', 'active'),

       ('seed_guest_1', '+10000000011', 'seed_guest_1@example.com', 'active'),
       ('seed_guest_2', '+10000000012', 'seed_guest_2@example.com', 'active'),
       ('seed_guest_3', '+10000000013', 'seed_guest_3@example.com', 'active'),
       ('seed_guest_4', '+10000000014', 'seed_guest_4@example.com', 'active'),
       ('seed_guest_5', '+10000000015', 'seed_guest_5@example.com', 'active'),
       ('seed_guest_blocked', '+10000000016', 'seed_guest_blocked@example.com', 'blocked'),
       ('seed_guest_pending', '+10000000017', 'seed_guest_pending@example.com', 'pending'),

       ('seed_admin_1', '+10000000021', 'seed_admin_1@example.com', 'active'),
       ('seed_admin_2', '+10000000022', 'seed_admin_2@example.com', 'active'),

       ('seed_power_user', '+10000000031', 'seed_power_user@example.com', 'active')
ON CONFLICT (username) DO NOTHING;

-- ============================================================================
-- 2. Ролевые привязки пользователей
-- ============================================================================
-- Владелец: все owner-аккаунты + power_user.
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
JOIN roles r ON r.name = 'owner'
WHERE u.username IN ('seed_owner_1', 'seed_owner_2', 'seed_owner_3', 'seed_owner_4', 'seed_power_user')
ON CONFLICT (user_id, role_id) DO NOTHING;

-- Гость: все guest-аккаунты + power_user.
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
JOIN roles r ON r.name = 'guest'
WHERE u.username IN ('seed_guest_1', 'seed_guest_2', 'seed_guest_3', 'seed_guest_4', 'seed_guest_5', 'seed_guest_blocked', 'seed_guest_pending', 'seed_power_user')
ON CONFLICT (user_id, role_id) DO NOTHING;

-- Администратор: админ-аккаунты.
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
JOIN roles r ON r.name = 'admin'
WHERE u.username IN ('seed_admin_1', 'seed_admin_2')
ON CONFLICT (user_id, role_id) DO NOTHING;

-- ============================================================================
-- 3. Адреса объектов
-- ============================================================================
-- Добавляем адреса в разных странах/городах для географически разнообразной выборки.
INSERT INTO addresses (city_id, street_line1, street_line2, region, postal_code, link)
SELECT c.id, v.street_line1, v.street_line2, v.region, v.postal_code, v.link
FROM (VALUES
         ('US', 'New York',         '5th Avenue, 1',           NULL,              'NY',  '10001', 'https://maps.example/ny-1'),
         ('US', 'San Francisco',    'Market Street, 221',      'Apt 12',          'CA',  '94103', 'https://maps.example/sf-1'),
         ('DE', 'Berlin',           'Unter den Linden, 10',    NULL,              'BE',  '10117', 'https://maps.example/berlin-1'),
         ('RU', 'Moscow',           'Tverskaya, 7',            'Building A',      'MOW', '125009', 'https://maps.example/msk-1'),
         ('GB', 'London',           'Soho Square, 8',          NULL,              'LND', 'W1D 3QD', 'https://maps.example/london-1'),
         ('FR', 'Paris',            'Rue de Rivoli, 101',      NULL,              'IDF', '75001', 'https://maps.example/paris-1'),
         ('JP', 'Tokyo',            'Shinjuku 3-15-11',        'Tower 2',         'TK',  '160-0022', 'https://maps.example/tokyo-1'),
         ('AE', 'Dubai',            'Marina Walk, 42',         'Suite 1901',      'DU',  '00000', 'https://maps.example/dubai-1'),
         ('ES', 'Barcelona',        'Passeig de Gracia, 55',   NULL,              'CAT', '08007', 'https://maps.example/barcelona-1'),
         ('IT', 'Rome',             'Via del Corso, 120',      NULL,              'RM',  '00186', 'https://maps.example/rome-1')
     ) AS v(country_code, city_name, street_line1, street_line2, region, postal_code, link)
JOIN countries co ON co.code = v.country_code
JOIN cities c ON c.country_id = co.id AND c.name = v.city_name
WHERE NOT EXISTS (
    SELECT 1
    FROM addresses a
    WHERE a.city_id = c.id
      AND a.street_line1 = v.street_line1
);

-- ============================================================================
-- 4. Объявления (listings)
-- ============================================================================
-- Добавляем объявления с разными статусами публикации:
-- active / hidden / blocked.
INSERT INTO listings (owner_id, object_type_id, address_id, capacity, number_of_rooms, description, status)
SELECT u.id,
       ot.id,
       a.id,
       v.capacity,
       v.rooms,
       v.description,
       v.status::listing_publication_status
FROM (VALUES
         ('seed_owner_1', 'apartment',  '5th Avenue, 1',         2, 1, 'Seed listing NY Manhattan',      'active'),
         ('seed_owner_1', 'studio',     'Market Street, 221',    2, 1, 'Seed listing SF Downtown',       'active'),
         ('seed_owner_2', 'house',      'Unter den Linden, 10',  6, 4, 'Seed listing Berlin Mitte',      'active'),
         ('seed_owner_3', 'loft',       'Rue de Rivoli, 101',    4, 2, 'Seed listing Paris Rivoli',      'active'),
         ('seed_owner_2', 'townhouse',  'Soho Square, 8',        5, 3, 'Seed listing London Soho',       'active'),
         ('seed_owner_4', 'villa',      'Marina Walk, 42',       8, 5, 'Seed listing Dubai Marina',      'active'),
         ('seed_owner_3', 'apartment',  'Tverskaya, 7',          3, 2, 'Seed listing Moscow Center',     'hidden'),
         ('seed_owner_4', 'studio',     'Shinjuku 3-15-11',      2, 1, 'Seed listing Tokyo Shinjuku',    'blocked'),
         ('seed_power_user', 'guesthouse', 'Passeig de Gracia, 55', 4, 2, 'Seed listing Barcelona Center', 'active'),
         ('seed_power_user', 'cabin',   'Via del Corso, 120',    3, 2, 'Seed listing Rome Corso',        'hidden')
     ) AS v(owner_username, object_type_name, street_line1, capacity, rooms, description, status)
JOIN users u ON u.username = v.owner_username
JOIN object_types ot ON ot.name = v.object_type_name
JOIN addresses a ON a.street_line1 = v.street_line1
WHERE NOT EXISTS (
    SELECT 1
    FROM listings l
    WHERE l.owner_id = u.id
      AND l.address_id = a.id
);

-- ============================================================================
-- 5. Фото объявлений
-- ============================================================================
-- Для ряда объявлений добавляем несколько фотографий (слоты 1..3),
-- чтобы покрыть сценарии галереи и ограничений по слотам.
INSERT INTO photos (extension, link)
VALUES ('jpeg', 'https://images.example/ny-manhattan-1.jpg'),
       ('jpeg', 'https://images.example/ny-manhattan-2.jpg'),
       ('jpeg', 'https://images.example/sf-downtown-1.jpg'),
       ('jpeg', 'https://images.example/sf-downtown-2.jpg'),
       ('jpeg', 'https://images.example/berlin-mitte-1.jpg'),
       ('jpeg', 'https://images.example/berlin-mitte-2.jpg'),
       ('jpeg', 'https://images.example/paris-rivoli-1.jpg'),
       ('jpeg', 'https://images.example/london-soho-1.jpg'),
       ('jpeg', 'https://images.example/dubai-marina-1.jpg'),
       ('png',  'https://images.example/moscow-center-1.png'),
       ('png',  'https://images.example/tokyo-shinjuku-1.png'),
       ('jpeg', 'https://images.example/barcelona-center-1.jpg')
ON CONFLICT (link) DO NOTHING;

INSERT INTO listing_photos (listing_id, photo_id, slot)
SELECT l.id, p.id, v.slot
FROM (VALUES
         ('Seed listing NY Manhattan',   'https://images.example/ny-manhattan-1.jpg',    1),
         ('Seed listing NY Manhattan',   'https://images.example/ny-manhattan-2.jpg',    2),
         ('Seed listing SF Downtown',    'https://images.example/sf-downtown-1.jpg',     1),
         ('Seed listing SF Downtown',    'https://images.example/sf-downtown-2.jpg',     2),
         ('Seed listing Berlin Mitte',   'https://images.example/berlin-mitte-1.jpg',    1),
         ('Seed listing Berlin Mitte',   'https://images.example/berlin-mitte-2.jpg',    2),
         ('Seed listing Paris Rivoli',   'https://images.example/paris-rivoli-1.jpg',    1),
         ('Seed listing London Soho',    'https://images.example/london-soho-1.jpg',     1),
         ('Seed listing Dubai Marina',   'https://images.example/dubai-marina-1.jpg',    1),
         ('Seed listing Moscow Center',  'https://images.example/moscow-center-1.png',   1),
         ('Seed listing Tokyo Shinjuku', 'https://images.example/tokyo-shinjuku-1.png',  1),
         ('Seed listing Barcelona Center','https://images.example/barcelona-center-1.jpg',1)
     ) AS v(listing_description, photo_link, slot)
JOIN listings l ON l.description = v.listing_description
JOIN photos p ON p.link = v.photo_link
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 6. Базовые цены
-- ============================================================================
-- По одному базовому прайсу на объявление (base_prices.listing_id UNIQUE).
INSERT INTO base_prices (currency_id, amount_in_minor, listing_id)
SELECT c.id, v.amount_in_minor, l.id
FROM (VALUES
         ('USD', 18000,  'Seed listing NY Manhattan'),
         ('USD', 14000,  'Seed listing SF Downtown'),
         ('EUR', 21000,  'Seed listing Berlin Mitte'),
         ('EUR', 19000,  'Seed listing Paris Rivoli'),
         ('GBP', 23000,  'Seed listing London Soho'),
         ('AED', 75000,  'Seed listing Dubai Marina'),
         ('RUB', 850000, 'Seed listing Moscow Center'),
         ('JPY', 1800000,'Seed listing Tokyo Shinjuku'),
         ('EUR', 16000,  'Seed listing Barcelona Center'),
         ('EUR', 13000,  'Seed listing Rome Corso')
     ) AS v(currency_code, amount_in_minor, listing_description)
JOIN currencies c ON c.code = v.currency_code
JOIN listings l ON l.description = v.listing_description
ON CONFLICT (listing_id) DO UPDATE
SET currency_id = EXCLUDED.currency_id,
    amount_in_minor = EXCLUDED.amount_in_minor,
    last_update_date = now();

-- ============================================================================
-- 7. Доступность по дням
-- ============================================================================
-- Для активных объявлений: 90 дней вперед со статусом available.
INSERT INTO listing_availability_days (available_date, status, listing_id)
SELECT gs::date,
       'available'::availability_status,
       l.id
FROM listings l
CROSS JOIN generate_series(current_date + 1, current_date + 90, interval '1 day') AS gs
WHERE l.status = 'active'
ON CONFLICT (listing_id, available_date) DO NOTHING;

-- Для hidden/blocked объявлений: создаем 45 дней со статусом blocked,
-- чтобы можно было тестировать фильтрацию недоступных вариантов.
INSERT INTO listing_availability_days (available_date, status, listing_id)
SELECT gs::date,
       'blocked'::availability_status,
       l.id
FROM listings l
CROSS JOIN generate_series(current_date + 1, current_date + 45, interval '1 day') AS gs
WHERE l.status IN ('hidden', 'blocked')
ON CONFLICT (listing_id, available_date) DO NOTHING;

-- Периодические блокировки для активных объявлений (техобслуживание/уборка):
-- каждая 10-я дата на горизонте переводится в blocked.
UPDATE listing_availability_days d
SET status = 'blocked',
    last_update_date = now()
FROM listings l
WHERE d.listing_id = l.id
  AND l.status = 'active'
  AND d.status = 'available'
  AND ((d.available_date - current_date) % 10 = 0);

-- Дневные override-цены на выходные для части объявлений:
-- если override_* = NULL, используется base_price;
-- если заполнено, действует дневная спец-цена.
UPDATE listing_availability_days d
SET override_currency_id = c.id,
    override_in_minor = bp.amount_in_minor + v.delta_in_minor,
    last_update_date = now()
FROM listings l
JOIN base_prices bp ON bp.listing_id = l.id
JOIN currencies c ON c.id = bp.currency_id
JOIN (VALUES
         ('Seed listing NY Manhattan', 3000),
         ('Seed listing Berlin Mitte', 2500),
         ('Seed listing Dubai Marina', 10000)
     ) AS v(listing_description, delta_in_minor)
  ON v.listing_description = l.description
WHERE d.listing_id = l.id
  AND d.status = 'available'
  AND EXTRACT(ISODOW FROM d.available_date) IN (5, 6)
  AND d.available_date <= current_date + 60;

COMMIT;
