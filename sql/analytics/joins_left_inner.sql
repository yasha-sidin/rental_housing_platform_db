-- joins_left_inner.sql
-- Домашнее задание: DML в PostgreSQL.
--
-- Условие:
-- Написать запрос по своей базе с использованием LEFT JOIN и INNER JOIN.
-- Объяснить, как порядок соединений в FROM влияет на результат и почему.
--
-- Выбранный сценарий:
-- Построить отчет по бронированиям: кто создал бронь, есть ли платеж и есть ли
-- отзыв. INNER JOIN используется для обязательной связи брони с пользователем,
-- а LEFT JOIN сохраняет бронирования без платежа или отзыва.
--
-- Реализация:

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

-- Вывод о порядке соединений:
-- В LEFT JOIN порядок важен: сохраняются строки левой таблицы. В этом запросе
-- первой стоит bookings, поэтому в результат попадают бронирования даже без
-- платежа или отзыва.
-- Для INNER JOIN порядок обычно не меняет итоговый набор строк,
-- потому что остаются только совпавшие пары.
