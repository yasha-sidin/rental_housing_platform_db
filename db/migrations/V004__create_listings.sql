-- V004: таблица объявлений/объектов недвижимости.
-- Зависимости: users (V003), object_types/addresses/listing_publication_status (V002).

CREATE TABLE listings
(
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_id         BIGINT                     NOT NULL REFERENCES users (id),
    object_type_id   BIGINT                     NOT NULL REFERENCES object_types (id),
    address_id       BIGINT UNIQUE              NOT NULL REFERENCES addresses (id),
    capacity         INT                        NOT NULL,
    number_of_rooms  INT                        NOT NULL,
    description      VARCHAR(1024),
    status           listing_publication_status NOT NULL DEFAULT 'hidden',
    creation_date    TIMESTAMPTZ                NOT NULL DEFAULT now(),
    last_update_date TIMESTAMPTZ                NOT NULL DEFAULT now(),
    -- Проверка гарантирует, что вместимость объекта положительная.
    CONSTRAINT chk_listings_capacity_positive CHECK (capacity > 0),
    -- Проверка гарантирует, что количество комнат не может быть отрицательным.
    CONSTRAINT chk_listings_number_of_rooms_non_negative CHECK (number_of_rooms >= 0),
    -- Проверка не позволяет поставить время обновления раньше времени создания.
    CONSTRAINT chk_listings_update_not_before_create CHECK (last_update_date >= creation_date)
);
