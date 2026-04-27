-- 999_cleanup.sql
-- Полная очистка только тех таблиц, которые заполняются seed-скриптами.
-- Таблицы, заполняемые миграциями (roles, permissions, role_permissions и др.),
-- намеренно НЕ очищаются.

TRUNCATE TABLE
    application.reviews,
    application.payments,
    application.booking_days,
    application.bookings,
    application.price_history,
    application.listing_availability_days,
    application.base_prices,
    application.listing_photos,
    application.photos,
    application.listings,
    application.addresses,
    application.user_roles,
    application.users,
    application.cities,
    application.countries,
    application.currencies,
    application.object_types
    RESTART IDENTITY CASCADE;
