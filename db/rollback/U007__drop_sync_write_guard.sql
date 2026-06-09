SET search_path = application, public;

DO
$$
DECLARE
    table_record RECORD;
BEGIN
    FOR table_record IN
        SELECT schemaname, tablename
        FROM pg_tables
        WHERE schemaname = 'application'
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS trg_enforce_two_sync_standbys_for_write ON %I.%I',
            table_record.schemaname,
            table_record.tablename
        );
    END LOOP;
END;
$$;

DROP FUNCTION IF EXISTS application.enforce_two_sync_standbys_for_write();
