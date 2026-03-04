-- 999_cleanup.sql
-- Полная очистка только тех таблиц, которые заполняются seed-скриптами.
-- Таблицы, заполняемые миграциями (roles, permissions, role_permissions и др.),
-- намеренно НЕ очищаются.

TRUNCATE TABLE
    public.reviews,
    public.payments,
    public.booking_days,
    public.bookings,
    public.price_history,
    public.listing_availability_days,
    public.base_prices,
    public.listing_photos,
    public.photos,
    public.listings,
    public.addresses,
    public.user_roles,
    public.users,
    public.cities,
    public.countries,
    public.currencies,
    public.object_types
    RESTART IDENTITY CASCADE;
