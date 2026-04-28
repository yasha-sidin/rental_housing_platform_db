SET search_path = application, public;

SELECT
    subname,
    subenabled,
    subslotname,
    subpublications
FROM pg_subscription
ORDER BY subname;

SELECT
    subname,
    pid,
    received_lsn,
    latest_end_lsn,
    latest_end_time
FROM pg_stat_subscription
ORDER BY subname;

SELECT
    code,
    name,
    last_update_date
FROM application.currencies
WHERE code IN ('XLG', 'XPH')
ORDER BY code;

SELECT
    count(*) AS replicated_currencies
FROM application.currencies;
