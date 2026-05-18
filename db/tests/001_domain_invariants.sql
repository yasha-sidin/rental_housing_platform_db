SET search_path = application, public;

SELECT 'completed bookings may have reviews' AS check_name,
       count(*) AS rows_checked
FROM reviews r
         JOIN bookings b ON b.id = r.booking_id
WHERE b.status = 'completed';

SELECT 'no active booking day overlaps' AS check_name,
       count(*) AS conflict_count
FROM (
         SELECT bd.availability_day_id
         FROM booking_days bd
                  JOIN bookings b ON b.id = bd.booking_id
         WHERE b.status IN ('created', 'payment_pending', 'confirmed')
         GROUP BY bd.availability_day_id
         HAVING count(*) > 1
     ) conflicts;

SELECT 'pitr marker exists' AS check_name,
       count(*) AS marker_count
FROM users
WHERE username = 'pitr_guard_user';
