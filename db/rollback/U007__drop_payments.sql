-- U007: откат платежей из V007.

DROP TRIGGER IF EXISTS trg_payments_require_not_expired_booking ON payments;
DROP FUNCTION IF EXISTS trg_payments_require_not_expired_booking();

DROP TABLE IF EXISTS payments;

DROP TYPE IF EXISTS payment_status;
