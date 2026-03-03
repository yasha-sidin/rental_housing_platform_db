-- V004: таблица объявлений/объектов недвижимости.
-- Зависимости: users (V003), object_types/addresses/listing_publication_status (V002).

CREATE TABLE listings
(
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_id         BIGINT                     NOT NULL REFERENCES users (id),
    object_type_id   BIGINT                     NOT NULL REFERENCES object_types (id),
    address_id       BIGINT                     NOT NULL REFERENCES addresses (id),
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

-- Справочник фотографий.
CREATE TABLE photos
(
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    extension     photo_extension     NOT NULL,
    link          VARCHAR(256) UNIQUE NOT NULL,
    creation_date TIMESTAMPTZ         NOT NULL DEFAULT now(),
    -- Проверка запрещает пустую ссылку.
    CONSTRAINT chk_photos_link_not_blank CHECK (btrim(link) <> '')
);

-- Привязка фото к объявлениям.
CREATE TABLE listing_photos
(
    listing_id BIGINT   NOT NULL REFERENCES listings (id) ON DELETE CASCADE,
    photo_id   BIGINT   NOT NULL REFERENCES photos (id) ON DELETE CASCADE,
    slot       SMALLINT NOT NULL,
    PRIMARY KEY (listing_id, photo_id),
    -- Фото не может быть привязано к двум объявлениям одновременно.
    CONSTRAINT uq_listing_photos_photo UNIQUE (photo_id),
    -- Слот строго от 1 до 20.
    CONSTRAINT chk_listing_photos_slot_range CHECK (slot BETWEEN 1 AND 20),
    -- В одном объявлении один слот может быть занят только одним фото.
    CONSTRAINT uq_listing_photos_listing_slot UNIQUE (listing_id, slot)
);

-- Триггерная защита от физического удаления объявлений.
-- Бизнес-правило ТЗ: объявления не удаляются, а переводятся в нужный статус публикации.
CREATE OR REPLACE FUNCTION trg_listings_prevent_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN
    -- Этап 1: блокируем физическое удаление любой строки объявления.
    RAISE EXCEPTION
        'physical delete is forbidden for listings (listing_id=%). Use status update instead.',
        OLD.id;
END;
$$;

CREATE TRIGGER trg_listings_prevent_delete
    BEFORE DELETE
    ON listings
    FOR EACH ROW
EXECUTE FUNCTION trg_listings_prevent_delete();
