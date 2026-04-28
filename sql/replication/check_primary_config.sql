SET search_path = application, public;

SELECT
    name,
    setting,
    source,
    sourcefile
FROM pg_settings
WHERE name IN (
    'data_directory',
    'listen_addresses',
    'wal_level',
    'max_wal_senders',
    'max_replication_slots',
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
    line_number,
    type,
    database,
    user_name,
    address,
    auth_method,
    error
FROM pg_hba_file_rules
ORDER BY line_number;
