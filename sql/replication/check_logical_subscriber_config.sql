SELECT
    name,
    setting,
    source,
    sourcefile
FROM pg_settings
WHERE name IN (
    'data_directory',
    'listen_addresses',
    'max_logical_replication_workers',
    'max_sync_workers_per_subscription',
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
