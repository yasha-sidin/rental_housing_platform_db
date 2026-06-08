SET search_path = application, public;

CREATE OR REPLACE FUNCTION application.enforce_two_sync_standbys_for_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, application, public, pg_temp
AS
$$
DECLARE
    v_is_primary BOOLEAN;
    v_sync_standbys INTEGER;
    v_synchronous_commit TEXT;
BEGIN
    SELECT NOT pg_is_in_recovery() INTO v_is_primary;

    IF NOT v_is_primary THEN
        RAISE EXCEPTION 'application write is allowed only on PostgreSQL primary'
            USING ERRCODE = '25006';
    END IF;

    SELECT current_setting('synchronous_commit') INTO v_synchronous_commit;

    IF v_synchronous_commit IN ('off', 'local') THEN
        RAISE EXCEPTION 'application write requires synchronous_commit, current value: %', v_synchronous_commit
            USING ERRCODE = '55000';
    END IF;

    SELECT count(*)::INTEGER
    INTO v_sync_standbys
    FROM pg_stat_replication
    WHERE state = 'streaming'
      AND sync_state = 'sync';

    IF v_sync_standbys < 2 THEN
        RAISE EXCEPTION 'application write requires at least 2 synchronous standbys, current sync standbys: %', v_sync_standbys
            USING ERRCODE = '55000';
    END IF;

    RETURN NULL;
END;
$$;

REVOKE EXECUTE ON FUNCTION application.enforce_two_sync_standbys_for_write() FROM PUBLIC;

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
        EXECUTE format(
            'CREATE TRIGGER trg_enforce_two_sync_standbys_for_write BEFORE INSERT OR UPDATE OR DELETE ON %I.%I FOR EACH STATEMENT EXECUTE FUNCTION application.enforce_two_sync_standbys_for_write()',
            table_record.schemaname,
            table_record.tablename
        );
    END LOOP;
END;
$$;
