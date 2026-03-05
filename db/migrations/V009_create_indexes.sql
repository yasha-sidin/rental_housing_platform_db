-- Подключаем расширение pg_trgm для ускорения поиска по подстроке (ILIKE '%...%').
CREATE EXTENSION IF NOT EXISTS pg_trgm;
----------------------------------------------------------------

-- Таблица roles
-- Не создаем индекс, так как CONSTRAINT UNIQUE уже означает создание b-tree индекса для поля name
----------------------------------------------------------------

-- Таблица permissions
-- Не создаем индекс, так как CONSTRAINT UNIQUE уже означает создание b-tree индекса для поля name
----------------------------------------------------------------

-- Таблица object_types
-- Не создаем индекс, так как CONSTRAINT UNIQUE уже означает создание b-tree индекса для поля name
----------------------------------------------------------------

-- Таблица countries
-- Создаем индекс для поиска по префиксу, например, LIKE 'ger%'
-- В запросе используем WHERE lower(name) LIKE 'ger%'
CREATE INDEX idx_countries_name_lower ON countries (lower(name));
----------------------------------------------------------------

-- Таблица cities
-- CONSTRAINT uq_cities_country_name UNIQUE (country_id, name) - уже есть, гарантирует быстрое соединение с
-- таблицей countries, так как country_id стоит на первом месте
-- Создаем индекс для поиска по префиксу, например, LIKE 'mos%'
-- В запросе используем WHERE lower(name) LIKE 'mos%'
CREATE INDEX idx_cities_name_lower ON cities (lower(name));
----------------------------------------------------------------

-- Таблица addresses
-- Создаем индекс для быстрого поиска по городу
CREATE INDEX idx_addresses_city_id ON addresses (city_id);
-- Создаем индекс для поиска по улице (ILIKE '%...%')
CREATE INDEX idx_addresses_street_line1_trgm ON addresses USING GIN ((coalesce(street_line1, '')) gin_trgm_ops);
-- Создаем индекс для поиска по префиксу postal_code и городу (будет работать и для поиска только по префиксу postal_code)
-- В запросе используем WHERE lower(postal_code) LIKE '32334%' AND city_id = 1
CREATE INDEX idx_addresses_postal_code_city_id ON addresses (lower(postal_code), city_id);
----------------------------------------------------------------

-- Таблица currencies
-- Создаем индекс для быстрого поиска активных валют
CREATE INDEX idx_currencies_is_active_true ON currencies (id) WHERE is_active = true;
----------------------------------------------------------------

-- Таблица users
-- Создаем индекс для быстрого поиска по статусу
CREATE INDEX idx_users_status ON users (status);
----------------------------------------------------------------

-- Таблица role_permissions
-- PRIMARY KEY (role_id, permission_id) - уже является индексом
----------------------------------------------------------------

-- Таблица user_roles
-- PRIMARY KEY (user_id, role_id) - уже является индексом
----------------------------------------------------------------

-- Таблица listings
-- Создаем индекс для быстрого поиска всех объявлений пользователя
CREATE INDEX idx_listings_owner_id ON listings (owner_id);
-- Создаем индекс для быстрого поиска по типу объекта
CREATE INDEX idx_listings_object_type_id ON listings (object_type_id);
-- Создаем индекс для быстрого поиска всех объявлений по адресу
CREATE INDEX idx_listings_address_id ON listings (address_id);
-- Создаем индекс для быстрого поиска по статусу
CREATE INDEX idx_listings_status ON listings (status);
----------------------------------------------------------------

-- Таблица photos
-- Нет необходимости в индексах
----------------------------------------------------------------

-- Таблица listing_photos
-- PRIMARY KEY (listing_id, photo_id) - уже подразумевает индекс
----------------------------------------------------------------

-- Таблица base_prices
-- listing_id - UNIQUE, поэтому уже можно быстро найти цену объявления
----------------------------------------------------------------

-- Таблица listing_availability_days
-- UNIQUE (listing_id, available_date) - уже создает индекс, который позволяет быстро найти все дни по объявлению
----------------------------------------------------------------

-- Таблица price_history
-- Создаем индекс, который позволит увидеть всю историю изменения цены по объявлению
CREATE INDEX idx_price_history_listing_id ON price_history (listing_id);
----------------------------------------------------------------

-- Таблица bookings
-- Создаем индекс для быстрого поиска бронирований по объявлению
CREATE INDEX idx_bookings_listing_id ON bookings (listing_id);
-- Создаем индекс для сортировки бронирований гостя в обратном порядке, полезно для просмотра последних бронирований гостя
CREATE INDEX idx_bookings_creation_date_desc_created_by_user ON bookings (creation_date DESC, created_by_user_id);
-- Создаем индекс для быстрого поиска по статусам
CREATE INDEX idx_bookings_status ON bookings (status);
----------------------------------------------------------------

-- Таблица booking_days
-- Создаем индекс для ускорения 4 этапа триггера trg_booking_days_prevent_active_overlap
CREATE INDEX idx_availability_day_id_listing_id_booking_id ON booking_days (availability_day_id, listing_id, booking_id);




