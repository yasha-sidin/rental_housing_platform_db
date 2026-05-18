SET search_path = application, public;

DROP TRIGGER IF EXISTS trg_reviews_require_completed_booking ON reviews;
DROP TRIGGER IF EXISTS trg_payments_require_not_expired_booking ON payments;
DROP TRIGGER IF EXISTS trg_booking_days_prevent_active_overlap ON booking_days;
DROP TRIGGER IF EXISTS trg_bookings_validate_status_transition ON bookings;

DROP FUNCTION IF EXISTS trg_reviews_require_completed_booking();
DROP FUNCTION IF EXISTS trg_payments_require_not_expired_booking();
DROP FUNCTION IF EXISTS trg_booking_days_prevent_active_overlap();
DROP FUNCTION IF EXISTS trg_bookings_validate_status_transition();

DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS booking_days CASCADE;
DROP TABLE IF EXISTS bookings CASCADE;

DROP TYPE IF EXISTS payment_status;
DROP TYPE IF EXISTS booking_status;
