SET search_path = application, public;

INSERT INTO application.currencies
(
    code,
    numeric_code,
    name,
    symbol,
    minor_unit,
    is_active,
    last_update_date
)
VALUES
(
    'XLG',
    '997',
    'Logical Replication Currency',
    'L$',
    2,
    true,
    now()
)
ON CONFLICT (code) DO UPDATE
SET
    name = EXCLUDED.name,
    symbol = EXCLUDED.symbol,
    is_active = EXCLUDED.is_active,
    last_update_date = now()
RETURNING id, code, name, last_update_date;
