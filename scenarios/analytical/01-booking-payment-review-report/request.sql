SET search_path = application, public;

SELECT
    booking.id AS booking_id,
    booking.status AS booking_status,
    guest.username AS guest_username,
    payment.id AS payment_id,
    payment.status AS payment_status,
    review.id AS review_id,
    review.mark AS review_mark
FROM bookings AS booking
INNER JOIN users AS guest ON guest.id = booking.created_by_user_id
LEFT JOIN payments AS payment ON payment.booking_id = booking.id
LEFT JOIN reviews AS review ON review.booking_id = booking.id
ORDER BY booking.id
LIMIT 10;

