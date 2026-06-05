SET search_path = application, public;

BEGIN;

INSERT INTO photos
    (extension, link, creation_date)
VALUES
    (
        'jpeg',
        'https://verification.example/photos/insert-returning-' ||
            to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') ||
            '.jpg',
        now()
    )
RETURNING id, extension, link, creation_date;

ROLLBACK;

