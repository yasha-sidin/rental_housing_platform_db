SET search_path = application, public;

BEGIN;

INSERT INTO users (username, phone_number, email, status)
VALUES ('owner_alice', '+10000000001', 'owner_alice@example.com', 'active'),
       ('owner_boris', '+10000000002', 'owner_boris@example.com', 'active'),
       ('guest_anna', '+10000000011', 'guest_anna@example.com', 'active'),
       ('guest_ivan', '+10000000012', 'guest_ivan@example.com', 'active'),
       ('admin_olga', '+10000000021', 'admin_olga@example.com', 'active')
ON CONFLICT (username) DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM (VALUES ('owner_alice', 'owner'),
             ('owner_boris', 'owner'),
             ('guest_anna', 'guest'),
             ('guest_ivan', 'guest'),
             ('admin_olga', 'admin')) AS v(username, role_name)
         JOIN users u ON u.username = v.username
         JOIN roles r ON r.name = v.role_name
ON CONFLICT DO NOTHING;

INSERT INTO addresses (city_id, street_line1, street_line2, region, postal_code, link)
SELECT c.id, v.street_line1, v.street_line2, v.region, v.postal_code, v.link
FROM (VALUES ('US', 'New York', '5th Avenue, 1', NULL, 'NY', '10001', 'https://maps.example/ny-1'),
             ('DE', 'Berlin', 'Unter den Linden, 10', NULL, 'BE', '10117', 'https://maps.example/berlin-1'),
             ('FR', 'Paris', 'Rue de Rivoli, 101', NULL, 'IDF', '75001', 'https://maps.example/paris-1'),
             ('GB', 'London', 'Soho Square, 8', NULL, 'LND', 'W1D 3QD', 'https://maps.example/london-1')) AS v(country_code, city_name, street_line1, street_line2, region, postal_code, link)
         JOIN countries co ON co.code = v.country_code
         JOIN cities c ON c.country_id = co.id AND c.name = v.city_name
WHERE NOT EXISTS (
    SELECT 1
    FROM addresses a
    WHERE a.city_id = c.id
      AND a.street_line1 = v.street_line1
);

INSERT INTO listings (owner_id, object_type_id, address_id, capacity, number_of_rooms, description, status)
SELECT u.id, ot.id, a.id, v.capacity, v.rooms, v.description, v.status::listing_publication_status
FROM (VALUES ('owner_alice', 'apartment', '5th Avenue, 1', 2, 1, 'Manhattan apartment near park', 'active'),
             ('owner_alice', 'loft', 'Rue de Rivoli, 101', 4, 2, 'Paris loft for family trip', 'active'),
             ('owner_boris', 'house', 'Unter den Linden, 10', 6, 4, 'Berlin house with workspace', 'active'),
             ('owner_boris', 'studio', 'Soho Square, 8', 2, 1, 'London studio hidden draft', 'hidden')) AS v(owner_username, object_type_name, street_line1, capacity, rooms, description, status)
         JOIN users u ON u.username = v.owner_username
         JOIN object_types ot ON ot.name = v.object_type_name
         JOIN addresses a ON a.street_line1 = v.street_line1
WHERE NOT EXISTS (
    SELECT 1
    FROM listings l
    WHERE l.owner_id = u.id
      AND l.address_id = a.id
);

INSERT INTO photos (extension, link)
VALUES ('jpeg', 'https://images.example/manhattan-1.jpg'),
       ('jpeg', 'https://images.example/manhattan-2.jpg'),
       ('jpeg', 'https://images.example/paris-1.jpg'),
       ('jpeg', 'https://images.example/berlin-1.jpg')
ON CONFLICT (link) DO NOTHING;

INSERT INTO listing_photos (listing_id, photo_id, slot)
SELECT l.id, p.id, v.slot
FROM (VALUES ('Manhattan apartment near park', 'https://images.example/manhattan-1.jpg', 1),
             ('Manhattan apartment near park', 'https://images.example/manhattan-2.jpg', 2),
             ('Paris loft for family trip', 'https://images.example/paris-1.jpg', 1),
             ('Berlin house with workspace', 'https://images.example/berlin-1.jpg', 1)) AS v(listing_description, photo_link, slot)
         JOIN listings l ON l.description = v.listing_description
         JOIN photos p ON p.link = v.photo_link
ON CONFLICT DO NOTHING;

INSERT INTO base_prices (currency_id, amount_in_minor, listing_id)
SELECT c.id, v.amount_in_minor, l.id
FROM (VALUES ('USD', 18000, 'Manhattan apartment near park'),
             ('EUR', 19000, 'Paris loft for family trip'),
             ('EUR', 21000, 'Berlin house with workspace'),
             ('GBP', 14000, 'London studio hidden draft')) AS v(currency_code, amount_in_minor, listing_description)
         JOIN currencies c ON c.code = v.currency_code
         JOIN listings l ON l.description = v.listing_description
ON CONFLICT (listing_id) DO UPDATE
    SET currency_id = EXCLUDED.currency_id,
        amount_in_minor = EXCLUDED.amount_in_minor,
        last_update_date = now();

INSERT INTO listing_availability_days (available_date, status, listing_id)
SELECT gs::date,
       CASE WHEN l.status = 'active' THEN 'available'::availability_status ELSE 'blocked'::availability_status END,
       l.id
FROM listings l
         CROSS JOIN generate_series(current_date + 1, current_date + 30, interval '1 day') AS gs
ON CONFLICT (listing_id, available_date) DO NOTHING;

COMMIT;
