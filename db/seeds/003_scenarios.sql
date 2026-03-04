-- 003_scenarios.sql
-- Сценарные данные для операционных и аналитических кейсов.
-- Здесь создаем разнообразные статусы бронирований и платежей,
-- а также отзывы и историю изменения цен.

DO
$$
DECLARE
    -- Листинги.
    v_listing_ny           BIGINT;
    v_listing_sf           BIGINT;
    v_listing_berlin       BIGINT;
    v_listing_paris        BIGINT;
    v_listing_london       BIGINT;
    v_listing_dubai        BIGINT;
    v_listing_barcelona    BIGINT;

    -- Пользователи.
    v_guest_1              BIGINT;
    v_guest_2              BIGINT;
    v_guest_3              BIGINT;
    v_guest_4              BIGINT;
    v_guest_5              BIGINT;
    v_owner_2              BIGINT;
    v_owner_4              BIGINT;
    v_admin_1              BIGINT;

    -- Валюты.
    v_usd_currency         BIGINT;
    v_eur_currency         BIGINT;
    v_gbp_currency         BIGINT;
    v_aed_currency         BIGINT;

    -- Дни доступности под сценарии.
    v_day_completed_1      BIGINT;
    v_day_completed_2      BIGINT;
    v_day_pending          BIGINT;
    v_day_created          BIGINT;
    v_day_confirmed        BIGINT;
    v_day_cancelled_guest  BIGINT;
    v_day_cancelled_owner  BIGINT;
    v_day_expired          BIGINT;
    v_day_failed_payment   BIGINT;

    -- Бронирования.
    v_booking_completed_1  BIGINT;
    v_booking_completed_2  BIGINT;
    v_booking_pending      BIGINT;
    v_booking_created      BIGINT;
    v_booking_confirmed    BIGINT;
    v_booking_cancel_guest BIGINT;
    v_booking_cancel_owner BIGINT;
    v_booking_expired      BIGINT;
    v_booking_failed       BIGINT;
BEGIN
    -- ========================================================================
    -- 0. Подготовка: ссылки и очистка старых сценарных записей
    -- ========================================================================
    -- Получаем ссылки на ключевые сущности.
    SELECT id INTO v_listing_ny        FROM listings WHERE description = 'Seed listing NY Manhattan' LIMIT 1;
    SELECT id INTO v_listing_sf        FROM listings WHERE description = 'Seed listing SF Downtown' LIMIT 1;
    SELECT id INTO v_listing_berlin    FROM listings WHERE description = 'Seed listing Berlin Mitte' LIMIT 1;
    SELECT id INTO v_listing_paris     FROM listings WHERE description = 'Seed listing Paris Rivoli' LIMIT 1;
    SELECT id INTO v_listing_london    FROM listings WHERE description = 'Seed listing London Soho' LIMIT 1;
    SELECT id INTO v_listing_dubai     FROM listings WHERE description = 'Seed listing Dubai Marina' LIMIT 1;
    SELECT id INTO v_listing_barcelona FROM listings WHERE description = 'Seed listing Barcelona Center' LIMIT 1;

    SELECT id INTO v_guest_1 FROM users WHERE username = 'seed_guest_1' LIMIT 1;
    SELECT id INTO v_guest_2 FROM users WHERE username = 'seed_guest_2' LIMIT 1;
    SELECT id INTO v_guest_3 FROM users WHERE username = 'seed_guest_3' LIMIT 1;
    SELECT id INTO v_guest_4 FROM users WHERE username = 'seed_guest_4' LIMIT 1;
    SELECT id INTO v_guest_5 FROM users WHERE username = 'seed_guest_5' LIMIT 1;

    SELECT id INTO v_owner_2 FROM users WHERE username = 'seed_owner_2' LIMIT 1;
    SELECT id INTO v_owner_4 FROM users WHERE username = 'seed_owner_4' LIMIT 1;
    SELECT id INTO v_admin_1 FROM users WHERE username = 'seed_admin_1' LIMIT 1;

    SELECT id INTO v_usd_currency FROM currencies WHERE code = 'USD' LIMIT 1;
    SELECT id INTO v_eur_currency FROM currencies WHERE code = 'EUR' LIMIT 1;
    SELECT id INTO v_gbp_currency FROM currencies WHERE code = 'GBP' LIMIT 1;
    SELECT id INTO v_aed_currency FROM currencies WHERE code = 'AED' LIMIT 1;

    IF v_listing_ny IS NULL OR v_listing_berlin IS NULL OR v_listing_london IS NULL THEN
        RAISE EXCEPTION 'Seed prerequisites not found. Run 001_reference.sql and 002_base_entities.sql first.';
    END IF;

    -- Удаляем предыдущие сценарные бронирования для seed-гостей и seed-листингов,
    -- чтобы сценарии были детерминированными при повторном запуске.
    DELETE FROM reviews
    WHERE booking_id IN (
        SELECT b.id
        FROM bookings b
        JOIN users u ON u.id = b.created_by_user_id
        WHERE u.username LIKE 'seed_guest_%'
    );

    DELETE FROM payments
    WHERE booking_id IN (
        SELECT b.id
        FROM bookings b
        JOIN users u ON u.id = b.created_by_user_id
        WHERE u.username LIKE 'seed_guest_%'
    );

    DELETE FROM booking_days
    WHERE booking_id IN (
        SELECT b.id
        FROM bookings b
        JOIN users u ON u.id = b.created_by_user_id
        WHERE u.username LIKE 'seed_guest_%'
    );

    DELETE FROM bookings
    WHERE created_by_user_id IN (
        SELECT id FROM users WHERE username LIKE 'seed_guest_%'
    );

    -- После очистки возвращаем все статусы дат активных объявлений в available,
    -- чтобы сценарии заново выставили нужные состояния.
    UPDATE listing_availability_days d
    SET status = 'available',
        last_update_date = now()
    FROM listings l
    WHERE d.listing_id = l.id
      AND l.status = 'active';

    -- ========================================================================
    -- 1. Подбор дат под сценарии
    -- ========================================================================
    SELECT id INTO v_day_completed_1
    FROM listing_availability_days
    WHERE listing_id = v_listing_ny AND status = 'available' AND available_date >= current_date + 1
    ORDER BY available_date
    LIMIT 1;

    SELECT id INTO v_day_completed_2
    FROM listing_availability_days
    WHERE listing_id = v_listing_paris AND status = 'available' AND available_date >= current_date + 2
    ORDER BY available_date
    LIMIT 1;

    SELECT id INTO v_day_pending
    FROM listing_availability_days
    WHERE listing_id = v_listing_ny AND status = 'available' AND available_date >= current_date + 3
    ORDER BY available_date
    LIMIT 1;

    SELECT id INTO v_day_created
    FROM listing_availability_days
    WHERE listing_id = v_listing_sf AND status = 'available' AND available_date >= current_date + 4
    ORDER BY available_date
    LIMIT 1;

    SELECT id INTO v_day_confirmed
    FROM listing_availability_days
    WHERE listing_id = v_listing_berlin AND status = 'available' AND available_date >= current_date + 5
    ORDER BY available_date
    LIMIT 1;

    SELECT id INTO v_day_cancelled_guest
    FROM listing_availability_days
    WHERE listing_id = v_listing_london AND status = 'available' AND available_date >= current_date + 6
    ORDER BY available_date
    LIMIT 1;

    SELECT id INTO v_day_cancelled_owner
    FROM listing_availability_days
    WHERE listing_id = v_listing_dubai AND status = 'available' AND available_date >= current_date + 7
    ORDER BY available_date
    LIMIT 1;

    SELECT id INTO v_day_expired
    FROM listing_availability_days
    WHERE listing_id = v_listing_barcelona AND status = 'available' AND available_date >= current_date + 8
    ORDER BY available_date
    LIMIT 1;

    SELECT id INTO v_day_failed_payment
    FROM listing_availability_days
    WHERE listing_id = v_listing_berlin AND status = 'available' AND available_date >= current_date + 9
    ORDER BY available_date
    LIMIT 1;

    IF v_day_completed_1 IS NULL OR v_day_pending IS NULL OR v_day_confirmed IS NULL THEN
        RAISE EXCEPTION 'Not enough available days for scenario seeds.';
    END IF;

    -- ========================================================================
    -- 2. Сценарий: completed + paid + review (unmoderated)
    -- ========================================================================
    INSERT INTO bookings (listing_id, created_by_user_id, guests_count, total_amount_currency_id, total_amount_in_minor, status, booking_expires_at)
    VALUES (v_listing_ny, v_guest_1, 2, v_usd_currency, 18000, 'created', now() + interval '4 minutes')
    RETURNING id INTO v_booking_completed_1;

    INSERT INTO booking_days (booking_id, availability_day_id, listing_id)
    VALUES (v_booking_completed_1, v_day_completed_1, v_listing_ny);

    UPDATE listing_availability_days
    SET status = 'booked', last_update_date = now()
    WHERE id = v_day_completed_1;

    UPDATE bookings
    SET status = 'completed', last_update_date = now()
    WHERE id = v_booking_completed_1;

    INSERT INTO payments (booking_id, currency_id, amount_in_minor, status, provider_payment_session_id, provider_payment_session_expires_at)
    VALUES (v_booking_completed_1, v_usd_currency, 18000, 'paid', 'seed-paid-completed-1', now() + interval '5 minutes');

    INSERT INTO reviews (booking_id, mark, body, moderated)
    VALUES (v_booking_completed_1, 5, 'Excellent apartment, smooth check-in.', false);

    -- ========================================================================
    -- 3. Сценарий: completed + paid + review (moderated)
    -- ========================================================================
    INSERT INTO bookings (listing_id, created_by_user_id, guests_count, total_amount_currency_id, total_amount_in_minor, status, booking_expires_at)
    VALUES (v_listing_paris, v_guest_2, 2, v_eur_currency, 20000, 'created', now() + interval '4 minutes')
    RETURNING id INTO v_booking_completed_2;

    INSERT INTO booking_days (booking_id, availability_day_id, listing_id)
    VALUES (v_booking_completed_2, v_day_completed_2, v_listing_paris);

    UPDATE listing_availability_days
    SET status = 'booked', last_update_date = now()
    WHERE id = v_day_completed_2;

    UPDATE bookings
    SET status = 'completed', last_update_date = now()
    WHERE id = v_booking_completed_2;

    INSERT INTO payments (booking_id, currency_id, amount_in_minor, status, provider_payment_session_id, provider_payment_session_expires_at)
    VALUES (v_booking_completed_2, v_eur_currency, 20000, 'paid', 'seed-paid-completed-2', now() + interval '5 minutes');

    INSERT INTO reviews (booking_id, mark, body, moderated, moderation_date)
    VALUES (v_booking_completed_2, 4, 'Good stay, small noise from street.', true, now());

    -- ========================================================================
    -- 4. Сценарий: payment_pending + initiated
    -- ========================================================================
    INSERT INTO bookings (listing_id, created_by_user_id, guests_count, total_amount_currency_id, total_amount_in_minor, status, booking_expires_at)
    VALUES (v_listing_ny, v_guest_3, 1, v_usd_currency, 17000, 'created', now() + interval '4 minutes')
    RETURNING id INTO v_booking_pending;

    INSERT INTO booking_days (booking_id, availability_day_id, listing_id)
    VALUES (v_booking_pending, v_day_pending, v_listing_ny);

    UPDATE listing_availability_days
    SET status = 'held', last_update_date = now()
    WHERE id = v_day_pending;

    UPDATE bookings
    SET status = 'payment_pending', last_update_date = now()
    WHERE id = v_booking_pending;

    INSERT INTO payments (booking_id, currency_id, amount_in_minor, status, provider_payment_session_id, provider_payment_session_expires_at)
    VALUES (v_booking_pending, v_usd_currency, 17000, 'initiated', 'seed-initiated-pending-1', now() + interval '5 minutes');

    -- ========================================================================
    -- 5. Сценарий: created без стартовавшего платежа
    -- ========================================================================
    INSERT INTO bookings (listing_id, created_by_user_id, guests_count, total_amount_currency_id, total_amount_in_minor, status, booking_expires_at)
    VALUES (v_listing_sf, v_guest_4, 1, v_usd_currency, 14000, 'created', now() + interval '4 minutes')
    RETURNING id INTO v_booking_created;

    INSERT INTO booking_days (booking_id, availability_day_id, listing_id)
    VALUES (v_booking_created, v_day_created, v_listing_sf);

    UPDATE listing_availability_days
    SET status = 'held', last_update_date = now()
    WHERE id = v_day_created;

    -- ========================================================================
    -- 6. Сценарий: confirmed + paid
    -- ========================================================================
    INSERT INTO bookings (listing_id, created_by_user_id, guests_count, total_amount_currency_id, total_amount_in_minor, status, booking_expires_at)
    VALUES (v_listing_berlin, v_guest_5, 3, v_eur_currency, 24000, 'created', now() + interval '4 minutes')
    RETURNING id INTO v_booking_confirmed;

    INSERT INTO booking_days (booking_id, availability_day_id, listing_id)
    VALUES (v_booking_confirmed, v_day_confirmed, v_listing_berlin);

    UPDATE bookings
    SET status = 'confirmed', last_update_date = now()
    WHERE id = v_booking_confirmed;

    UPDATE listing_availability_days
    SET status = 'booked', last_update_date = now()
    WHERE id = v_day_confirmed;

    INSERT INTO payments (booking_id, currency_id, amount_in_minor, status, provider_payment_session_id, provider_payment_session_expires_at)
    VALUES (v_booking_confirmed, v_eur_currency, 24000, 'paid', 'seed-paid-confirmed-1', now() + interval '5 minutes');

    -- ========================================================================
    -- 7. Сценарий: cancelled гостем до оплаты
    -- ========================================================================
    INSERT INTO bookings (listing_id, created_by_user_id, guests_count, total_amount_currency_id, total_amount_in_minor, status, booking_expires_at)
    VALUES (v_listing_london, v_guest_1, 2, v_gbp_currency, 25000, 'created', now() + interval '4 minutes')
    RETURNING id INTO v_booking_cancel_guest;

    INSERT INTO booking_days (booking_id, availability_day_id, listing_id)
    VALUES (v_booking_cancel_guest, v_day_cancelled_guest, v_listing_london);

    UPDATE listing_availability_days
    SET status = 'held', last_update_date = now()
    WHERE id = v_day_cancelled_guest;

    UPDATE bookings
    SET status = 'cancelled',
        cancelled_by_user_id = v_guest_1,
        cancellation_reason = 'guest changed plans',
        last_update_date = now()
    WHERE id = v_booking_cancel_guest;

    UPDATE listing_availability_days
    SET status = 'available', last_update_date = now()
    WHERE id = v_day_cancelled_guest;

    INSERT INTO payments (booking_id, currency_id, amount_in_minor, status, provider_payment_session_id, provider_payment_session_expires_at)
    VALUES (v_booking_cancel_guest, v_gbp_currency, 25000, 'cancelled', 'seed-cancelled-payment-1', now() + interval '5 minutes');

    -- ========================================================================
    -- 8. Сценарий: owner-cancelled confirmed + refunded
    -- ========================================================================
    INSERT INTO bookings (listing_id, created_by_user_id, guests_count, total_amount_currency_id, total_amount_in_minor, status, booking_expires_at)
    VALUES (v_listing_dubai, v_guest_2, 2, v_aed_currency, 76000, 'created', now() + interval '4 minutes')
    RETURNING id INTO v_booking_cancel_owner;

    INSERT INTO booking_days (booking_id, availability_day_id, listing_id)
    VALUES (v_booking_cancel_owner, v_day_cancelled_owner, v_listing_dubai);

    UPDATE bookings
    SET status = 'confirmed', last_update_date = now()
    WHERE id = v_booking_cancel_owner;

    UPDATE listing_availability_days
    SET status = 'booked', last_update_date = now()
    WHERE id = v_day_cancelled_owner;

    INSERT INTO payments (booking_id, currency_id, amount_in_minor, refunded_amount_in_minor, status, provider_payment_session_id, provider_payment_session_expires_at)
    VALUES (v_booking_cancel_owner, v_aed_currency, 76000, 76000, 'refunded', 'seed-refunded-owner-cancel-1', now() + interval '5 minutes');

    UPDATE bookings
    SET status = 'cancelled',
        cancelled_by_user_id = v_owner_4,
        cancellation_reason = 'owner maintenance issue',
        last_update_date = now()
    WHERE id = v_booking_cancel_owner;

    -- ========================================================================
    -- 9. Сценарий: expired + payment expired
    -- ========================================================================
    INSERT INTO bookings (listing_id, created_by_user_id, guests_count, total_amount_currency_id, total_amount_in_minor, status, booking_expires_at)
    VALUES (v_listing_barcelona, v_guest_3, 1, v_eur_currency, 17000, 'created', now() + interval '4 minutes')
    RETURNING id INTO v_booking_expired;

    INSERT INTO booking_days (booking_id, availability_day_id, listing_id)
    VALUES (v_booking_expired, v_day_expired, v_listing_barcelona);

    UPDATE listing_availability_days
    SET status = 'held', last_update_date = now()
    WHERE id = v_day_expired;

    INSERT INTO payments (booking_id, currency_id, amount_in_minor, status, provider_payment_session_id, provider_payment_session_expires_at)
    VALUES (v_booking_expired, v_eur_currency, 17000, 'expired', 'seed-expired-payment-1', now() + interval '5 minutes');

    UPDATE bookings
    SET status = 'expired', last_update_date = now()
    WHERE id = v_booking_expired;

    UPDATE listing_availability_days
    SET status = 'available', last_update_date = now()
    WHERE id = v_day_expired;

    -- ========================================================================
    -- 10. Сценарий: failed payment + booking cancelled
    -- ========================================================================
    INSERT INTO bookings (listing_id, created_by_user_id, guests_count, total_amount_currency_id, total_amount_in_minor, status, booking_expires_at)
    VALUES (v_listing_berlin, v_guest_4, 2, v_eur_currency, 23000, 'created', now() + interval '4 minutes')
    RETURNING id INTO v_booking_failed;

    INSERT INTO booking_days (booking_id, availability_day_id, listing_id)
    VALUES (v_booking_failed, v_day_failed_payment, v_listing_berlin);

    UPDATE listing_availability_days
    SET status = 'held', last_update_date = now()
    WHERE id = v_day_failed_payment;

    INSERT INTO payments (booking_id, currency_id, amount_in_minor, status, provider_payment_session_id, provider_payment_session_expires_at)
    VALUES (v_booking_failed, v_eur_currency, 23000, 'failed', 'seed-failed-payment-1', now() + interval '5 minutes');

    UPDATE bookings
    SET status = 'cancelled',
        cancelled_by_user_id = v_admin_1,
        cancellation_reason = 'payment failed repeatedly',
        last_update_date = now()
    WHERE id = v_booking_failed;

    UPDATE listing_availability_days
    SET status = 'available', last_update_date = now()
    WHERE id = v_day_failed_payment;

    -- ========================================================================
    -- 11. Дополнительный кейс: partially_refunded на отдельной брони
    -- ========================================================================
    INSERT INTO bookings (listing_id, created_by_user_id, guests_count, total_amount_currency_id, total_amount_in_minor, status, booking_expires_at)
    VALUES (v_listing_london, v_guest_5, 2, v_gbp_currency, 24000, 'created', now() + interval '4 minutes')
    RETURNING id INTO v_booking_cancel_owner;

    -- Берем любую available дату London, отличную от уже использованной.
    SELECT id INTO v_day_cancelled_owner
    FROM listing_availability_days
    WHERE listing_id = v_listing_london
      AND status = 'available'
      AND available_date >= current_date + 12
    ORDER BY available_date
    LIMIT 1;

    IF v_day_cancelled_owner IS NOT NULL THEN
        INSERT INTO booking_days (booking_id, availability_day_id, listing_id)
        VALUES (v_booking_cancel_owner, v_day_cancelled_owner, v_listing_london);

        UPDATE bookings
        SET status = 'confirmed', last_update_date = now()
        WHERE id = v_booking_cancel_owner;

        UPDATE listing_availability_days
        SET status = 'booked', last_update_date = now()
        WHERE id = v_day_cancelled_owner;

        INSERT INTO payments (booking_id, currency_id, amount_in_minor, refunded_amount_in_minor, status, provider_payment_session_id, provider_payment_session_expires_at)
        VALUES (v_booking_cancel_owner, v_gbp_currency, 24000, 7000, 'partially_refunded', 'seed-partial-refund-1', now() + interval '5 minutes');
    END IF;

    -- ========================================================================
    -- 12. Генерация price_history через изменения цен
    -- ========================================================================
    -- 12.1 Обновляем базовую цену для NY-листинга (триггер создаст запись в price_history).
    UPDATE base_prices bp
    SET amount_in_minor = bp.amount_in_minor + 500,
        last_update_date = now()
    WHERE bp.listing_id = v_listing_ny;

    -- 12.2 Обновляем override-цену для ближайшей available даты Berlin-листинга.
    UPDATE listing_availability_days d
    SET override_currency_id = v_eur_currency,
        override_in_minor = 27500,
        last_update_date = now()
    WHERE d.id = (
        SELECT d2.id
        FROM listing_availability_days d2
        WHERE d2.listing_id = v_listing_berlin
          AND d2.status = 'available'
          AND d2.available_date >= current_date + 15
        ORDER BY d2.available_date
        LIMIT 1
    );
END;
$$;
