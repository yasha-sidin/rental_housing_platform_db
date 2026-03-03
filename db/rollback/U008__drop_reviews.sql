-- U008: откат отзывов из V008.

DROP TRIGGER IF EXISTS trg_reviews_require_completed_booking ON reviews;
DROP FUNCTION IF EXISTS trg_reviews_require_completed_booking();

DROP TABLE IF EXISTS reviews;
