-- U004: откат listings и фото из V004.

DROP TRIGGER IF EXISTS trg_listings_prevent_delete ON listings;
DROP FUNCTION IF EXISTS trg_listings_prevent_delete();

DROP TABLE IF EXISTS listing_photos;
DROP TABLE IF EXISTS photos;
DROP TABLE IF EXISTS listings;
