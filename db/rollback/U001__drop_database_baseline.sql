DROP SCHEMA IF EXISTS application CASCADE;

DROP EXTENSION IF EXISTS pg_trgm;
DROP EXTENSION IF EXISTS pg_stat_statements;

DO
$$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_owner') THEN
        EXECUTE format('REVOKE app_owner FROM %I', CURRENT_USER);
    END IF;
EXCEPTION
    WHEN undefined_object THEN
        NULL;
END;
$$;

REVOKE app_readwrite FROM app_owner;
REVOKE app_readonly FROM app_readwrite;

DROP ROLE IF EXISTS app_owner;
DROP ROLE IF EXISTS app_readwrite;
DROP ROLE IF EXISTS app_readonly;
