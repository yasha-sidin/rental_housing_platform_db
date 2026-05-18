SET search_path = application, public;

CREATE TABLE users
(
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username      VARCHAR(128) UNIQUE NOT NULL,
    phone_number  VARCHAR(128) UNIQUE NOT NULL,
    email         VARCHAR(128) UNIQUE,
    register_date TIMESTAMPTZ         NOT NULL DEFAULT now(),
    status        user_status         NOT NULL,
    CONSTRAINT chk_users_username_not_blank CHECK (btrim(username) <> ''),
    CONSTRAINT chk_users_phone_not_blank CHECK (btrim(phone_number) <> ''),
    CONSTRAINT chk_users_email_not_blank CHECK (email IS NULL OR btrim(email) <> '')
);

CREATE TABLE user_roles
(
    user_id BIGINT NOT NULL REFERENCES users (id),
    role_id BIGINT NOT NULL REFERENCES roles (id),
    PRIMARY KEY (user_id, role_id)
);

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
    CONSTRAINT chk_listings_capacity_positive CHECK (capacity > 0),
    CONSTRAINT chk_listings_number_of_rooms_non_negative CHECK (number_of_rooms >= 0),
    CONSTRAINT chk_listings_update_not_before_create CHECK (last_update_date >= creation_date)
);

CREATE TABLE photos
(
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    extension     photo_extension     NOT NULL,
    link          VARCHAR(256) UNIQUE NOT NULL,
    creation_date TIMESTAMPTZ         NOT NULL DEFAULT now(),
    CONSTRAINT chk_photos_link_not_blank CHECK (btrim(link) <> '')
);

CREATE TABLE listing_photos
(
    listing_id BIGINT   NOT NULL REFERENCES listings (id) ON DELETE CASCADE,
    photo_id   BIGINT   NOT NULL REFERENCES photos (id) ON DELETE CASCADE,
    slot       SMALLINT NOT NULL,
    PRIMARY KEY (listing_id, photo_id),
    CONSTRAINT uq_listing_photos_photo UNIQUE (photo_id),
    CONSTRAINT chk_listing_photos_slot_range CHECK (slot BETWEEN 1 AND 20),
    CONSTRAINT uq_listing_photos_listing_slot UNIQUE (listing_id, slot)
);

CREATE OR REPLACE FUNCTION trg_listings_prevent_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = application, public, pg_temp
AS
$$
BEGIN
    RAISE EXCEPTION 'physical delete is forbidden for listings (listing_id=%). Use status update instead.', OLD.id;
END;
$$;

CREATE TRIGGER trg_listings_prevent_delete
    BEFORE DELETE ON listings
    FOR EACH ROW
EXECUTE FUNCTION trg_listings_prevent_delete();
