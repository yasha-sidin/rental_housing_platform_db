SET search_path = application, public;

SELECT
    pg_is_in_recovery() AS is_physical_standby,
    pg_last_wal_receive_lsn() AS received_lsn,
    pg_last_wal_replay_lsn() AS replayed_lsn,
    now() - pg_last_xact_replay_timestamp() AS replay_delay;

SELECT
    name,
    setting,
    source,
    sourcefile
FROM pg_settings
WHERE name IN (
    'data_directory',
    'hot_standby',
    'primary_slot_name',
    'recovery_min_apply_delay',
    'hba_file'
)
ORDER BY name;

SELECT
    sourcefile,
    name,
    setting,
    applied,
    error
FROM pg_file_settings
WHERE sourcefile LIKE '/etc/postgresql/%'
ORDER BY sourcefile, name;

SELECT
    code,
    name,
    last_update_date
FROM application.currencies
WHERE code IN ('XPH', 'XLG')
ORDER BY code;
