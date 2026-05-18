SET search_path = application, public;

DO
$$
DECLARE
    v_listing_manhattan BIGINT;
    v_listing_berlin BIGINT;
    v_guest_anna BIGINT;
    v_guest_ivan BIGINT;
    v_usd BIGINT;
    v_eur BIGINT;
    v_day_completed BIGINT;
    v_day_pending BIGINT;
    v_booking_completed BIGINT;
    v_booking_pending BIGINT;
BEGIN
    SELECT id INTO v_listing_manhattan FROM listings WHERE description = 'Manhattan apartment near park';
    SELECT id INTO v_listing_berlin FROM listings WHERE description = 'Berlin house with workspace';
    SELECT id INTO v_guest_anna FROM users WHERE username = 'guest_anna';
    SELECT id INTO v_guest_ivan FROM users WHERE username = 'guest_ivan';
    SELECT id INTO v_usd FROM currencies WHERE code = 'USD';
    SELECT id INTO v_eur FROM currencies WHERE code = 'EUR';

    DELETE FROM reviews WHERE booking_id IN (SELECT id FROM bookings WHERE created_by_user_id IN (v_guest_anna, v_guest_ivan));
    DELETE FROM payments WHERE booking_id IN (SELECT id FROM bookings WHERE created_by_user_id IN (v_guest_anna, v_guest_ivan));
    DELETE FROM booking_days WHERE booking_id IN (SELECT id FROM bookings WHERE created_by_user_id IN (v_guest_anna, v_guest_ivan));
    DELETE FROM bookings WHERE created_by_user_id IN (v_guest_anna, v_guest_ivan);

    UPDATE listing_availability_days
    SET status = 'available', last_update_date = now()
    WHERE listing_id IN (v_listing_manhattan, v_listing_berlin);

    SELECT id INTO v_day_completed
    FROM listing_availability_days
    WHERE listing_id = v_listing_manhattan
      AND available_date >= current_date + 1
    ORDER BY available_date
    LIMIT 1;

    SELECT id INTO v_day_pending
    FROM listing_availability_days
    WHERE listing_id = v_listing_berlin
      AND available_date >= current_date + 2
    ORDER BY available_date
    LIMIT 1;

    INSERT INTO bookings (listing_id, created_by_user_id, guests_count, total_amount_currency_id,
                          total_amount_in_minor, status, booking_expires_at)
    VALUES (v_listing_manhattan, v_guest_anna, 2, v_usd, 18000, 'created', now() + interval '4 minutes')
    RETURNING id INTO v_booking_completed;

    INSERT INTO booking_days (booking_id, availability_day_id, listing_id)
    VALUES (v_booking_completed, v_day_completed, v_listing_manhattan);

    UPDATE listing_availability_days SET status = 'booked', last_update_date = now() WHERE id = v_day_completed;
    UPDATE bookings SET status = 'completed', last_update_date = now() WHERE id = v_booking_completed;

    INSERT INTO payments (booking_id, currency_id, amount_in_minor, status, provider_payment_session_id,
                          provider_payment_session_expires_at)
    VALUES (v_booking_completed, v_usd, 18000, 'paid', 'seed-paid-completed-1', now() + interval '5 minutes');

    INSERT INTO reviews (booking_id, mark, body, moderated)
    VALUES (v_booking_completed, 5, 'Clean apartment and fast check-in.', false);

    INSERT INTO bookings (listing_id, created_by_user_id, guests_count, total_amount_currency_id,
                          total_amount_in_minor, status, booking_expires_at)
    VALUES (v_listing_berlin, v_guest_ivan, 3, v_eur, 21000, 'created', now() + interval '4 minutes')
    RETURNING id INTO v_booking_pending;

    INSERT INTO booking_days (booking_id, availability_day_id, listing_id)
    VALUES (v_booking_pending, v_day_pending, v_listing_berlin);

    UPDATE listing_availability_days SET status = 'held', last_update_date = now() WHERE id = v_day_pending;
    UPDATE bookings SET status = 'payment_pending', last_update_date = now() WHERE id = v_booking_pending;

    INSERT INTO payments (booking_id, currency_id, amount_in_minor, status, provider_payment_session_id,
                          provider_payment_session_expires_at)
    VALUES (v_booking_pending, v_eur, 21000, 'initiated', 'seed-initiated-pending-1', now() + interval '5 minutes');
END;
$$;
