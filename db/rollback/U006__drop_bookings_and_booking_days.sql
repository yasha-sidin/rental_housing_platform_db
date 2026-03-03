-- U006: откат бронирований и связей с днями из V006.

DROP TRIGGER IF EXISTS trg_booking_days_prevent_active_overlap ON booking_days;
DROP FUNCTION IF EXISTS trg_booking_days_prevent_active_overlap();

DROP TRIGGER IF EXISTS trg_listing_availability_days_block_status_change_on_active_hold ON listing_availability_days;
DROP FUNCTION IF EXISTS trg_listing_availability_days_block_status_change_on_active_hold();

DROP TRIGGER IF EXISTS trg_bookings_validate_status_transition ON bookings;
DROP FUNCTION IF EXISTS trg_bookings_validate_status_transition();

DROP TABLE IF EXISTS booking_days;
DROP TABLE IF EXISTS bookings;

DROP TYPE IF EXISTS booking_status;
