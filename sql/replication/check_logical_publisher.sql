SET search_path = application, public;

SELECT
    pubname,
    puballtables,
    pubinsert,
    pubupdate,
    pubdelete,
    pubtruncate
FROM pg_publication
ORDER BY pubname;

SELECT
    pubname,
    schemaname,
    tablename
FROM pg_publication_tables
ORDER BY pubname, schemaname, tablename;

SELECT
    code,
    name,
    last_update_date
FROM application.currencies
WHERE code IN ('XLG', 'XPH')
ORDER BY code;
