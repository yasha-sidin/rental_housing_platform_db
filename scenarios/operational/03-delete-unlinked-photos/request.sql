SET search_path = application, public;

BEGIN;

INSERT INTO photos (extension, link)
VALUES ('jpeg', 'https://verification.example/photos/delete-using-check.jpg')
ON CONFLICT (link) DO NOTHING;

DELETE FROM photos
USING (
    SELECT inner_photos.id, listing_photos.photo_id AS listing_photo_id
    FROM photos AS inner_photos
    LEFT JOIN listing_photos ON listing_photos.photo_id = inner_photos.id
    WHERE inner_photos.link LIKE 'https://verification.example/%'
) AS candidate_photos
WHERE candidate_photos.id = photos.id
  AND candidate_photos.listing_photo_id IS NULL
RETURNING
    photos.id,
    photos.extension,
    photos.link,
    photos.creation_date;

ROLLBACK;
