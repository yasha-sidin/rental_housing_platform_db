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
-- CONSTRAINT uq_cities_country_name UNIQUE (country_id, name) - уже есть.
-- Этот индекс ускоряет выборки городов внутри страны и проверки уникальности имени города в рамках страны.
-- Создаем индекс для поиска по префиксу, например, LIKE 'mos%'
-- В запросе используем WHERE lower(name) LIKE 'mos%'
CREATE INDEX idx_cities_name_lower ON cities (lower(name));
----------------------------------------------------------------

-- Таблица addresses
-- Создаем индекс для быстрого поиска по городу
CREATE INDEX idx_addresses_city_id ON addresses (city_id);
-- Создаем индекс для поиска по улице (ILIKE '%...%')
CREATE INDEX idx_addresses_street_line1_trgm ON addresses USING GIN ((coalesce(street_line1, '')) gin_trgm_ops);
-- Создаем составной индекс под частый сценарий: сначала фильтр по городу, затем поиск по префиксу postal_code.
-- В запросе используем WHERE city_id = 1 AND lower(postal_code) LIKE '32334%'.
-- Важно: для поиска только по postal_code без city_id этот индекс менее эффективен.
CREATE INDEX idx_addresses_city_id_postal_code ON addresses (city_id, lower(postal_code));
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
-- PRIMARY KEY (role_id, permission_id) - уже является индексом.
-- Создаем дополнительный индекс для быстрого поиска ролей по конкретному permission_id.
-- Это полезно для обратной проверки: "какие роли имеют это разрешение".
CREATE INDEX idx_role_permissions_permission_id ON role_permissions (permission_id);
----------------------------------------------------------------

-- Таблица user_roles
-- PRIMARY KEY (user_id, role_id) - уже является индексом.
-- Создаем дополнительный индекс для быстрого поиска пользователей по конкретной роли.
-- Это полезно для выборок вида "все пользователи с ролью owner/admin".
CREATE INDEX idx_user_roles_role_id ON user_roles (role_id);
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
-- Создаем индекс под выборку "бронирования конкретного гостя" с сортировкой по дате создания по убыванию.
-- Пример: WHERE created_by_user_id = ? ORDER BY creation_date DESC.
CREATE INDEX idx_bookings_created_by_user_creation_date_desc ON bookings (created_by_user_id, creation_date DESC);
-- Создаем индекс для быстрого поиска по статусам
CREATE INDEX idx_bookings_status ON bookings (status);
----------------------------------------------------------------

-- Таблица booking_days
-- Создаем индекс для ускорения проверки конфликта в trg_booking_days_prevent_active_overlap:
-- WHERE availability_day_id = ? AND listing_id = ? AND booking_id <> ?
CREATE INDEX idx_availability_day_id_listing_id_booking_id ON booking_days (availability_day_id, listing_id, booking_id);
----------------------------------------------------------------

-- Таблица payments
-- booking_id - UNIQUE, поэтому быстрый поиск платежа по бронированию уже обеспечен.
-- provider_payment_session_id - UNIQUE, поэтому идемпотентная обработка callback/webhook уже ускорена.
-- Создаем составной индекс под операционный сценарий проверки/закрытия платежных сессий:
-- WHERE status = 'initiated' AND provider_payment_session_expires_at < now().
-- Также подходит для выборок только по status за счет левого префикса индекса.
CREATE INDEX idx_payments_status_session_expires_at
    ON payments (status, provider_payment_session_expires_at);
----------------------------------------------------------------

-- Таблица reviews
-- booking_id - UNIQUE, поэтому быстрый доступ к отзыву по конкретному бронированию уже обеспечен.
-- Создаем partial index под очередь модерации:
-- WHERE moderated = false ORDER BY creation_date.
-- В индекс попадают только немодерированные отзывы, что уменьшает размер и ускоряет выборку очереди.
CREATE INDEX idx_reviews_unmoderated_creation_date
    ON reviews (creation_date)
    WHERE moderated = false;

