SET search_path = application, public;

ANALYZE users;
ANALYZE listings;
ANALYZE addresses;
ANALYZE bookings;

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    listing.id,
    listing.owner_id,
    listing.status,
    listing.description
FROM listings AS listing
WHERE listing.owner_id = (
    SELECT "user".id
    FROM users AS "user"
    WHERE "user".username = 'load_owner_500'
)
ORDER BY listing.id;

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    listing.id,
    listing.description,
    listing.status
FROM listings AS listing
WHERE to_tsvector('simple', coalesce(listing.description, ''))
      @@ plainto_tsquery('simple', 'Manhattan');

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    count(*) AS matching_active_listings
FROM listings AS listing
WHERE listing.status = 'active'
  AND listing.capacity = 2
  AND listing.number_of_rooms = 1;

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    address.id,
    address.city_id,
    address.postal_code,
    address.street_line1
FROM addresses AS address
WHERE address.city_id = 20
  AND lower(address.postal_code) = lower('010500');

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    booking.id,
    booking.created_by_user_id,
    booking.status,
    booking.creation_date
FROM bookings AS booking
WHERE booking.created_by_user_id = (
    SELECT "user".id
    FROM users AS "user"
    WHERE "user".username = 'load_guest_500'
)
ORDER BY booking.creation_date DESC
LIMIT 20;

