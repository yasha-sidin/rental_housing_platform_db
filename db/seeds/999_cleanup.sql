SET search_path = application, public;

TRUNCATE TABLE
    reviews,
    payments,
    booking_days,
    bookings,
    price_history,
    listing_availability_days,
    base_prices,
    listing_photos,
    photos,
    listings,
    addresses,
    user_roles,
    users,
    cities,
    countries,
    currencies,
    object_types
    RESTART IDENTITY CASCADE;
