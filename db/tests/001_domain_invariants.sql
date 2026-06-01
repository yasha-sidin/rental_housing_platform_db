SET search_path = application, public;

SELECT 'reviews without completed booking' AS check_name,
       count(*) AS violation_count
FROM reviews r
         JOIN bookings b ON b.id = r.booking_id
WHERE b.status <> 'completed';

SELECT 'active booking day overlaps' AS check_name,
       count(*) AS violation_count
FROM (
         SELECT bd.availability_day_id,
                bd.listing_id
         FROM booking_days bd
                  JOIN bookings b ON b.id = bd.booking_id
         WHERE b.status IN ('created', 'payment_pending', 'confirmed')
         GROUP BY bd.availability_day_id, bd.listing_id
         HAVING count(*) > 1
     ) conflicts;

SELECT 'payments after booking expiration' AS check_name,
       count(*) AS violation_count
FROM payments p
         JOIN bookings b ON b.id = p.booking_id
WHERE p.initiated_date > b.booking_expires_at;

SELECT 'booking day listing mismatch' AS check_name,
       count(*) AS violation_count
FROM booking_days bd
         JOIN bookings b ON b.id = bd.booking_id
         JOIN listing_availability_days lad ON lad.id = bd.availability_day_id
WHERE bd.listing_id <> b.listing_id
   OR bd.listing_id <> lad.listing_id;

SELECT 'price history listing mismatch' AS check_name,
       count(*) AS violation_count
FROM price_history ph
         JOIN listing_availability_days lad ON lad.id = ph.availability_day_id
WHERE ph.source = 'day_override'
  AND ph.listing_id <> lad.listing_id;

SELECT 'pitr marker exists' AS check_name,
       count(*) AS marker_count
FROM users
WHERE username = 'pitr_guard_user';
