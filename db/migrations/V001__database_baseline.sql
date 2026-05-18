CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE SCHEMA IF NOT EXISTS application;

DO
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_owner') THEN
        CREATE ROLE app_owner NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_readwrite') THEN
        CREATE ROLE app_readwrite NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_readonly') THEN
        CREATE ROLE app_readonly NOLOGIN;
    END IF;
END;
$$;

GRANT app_readonly TO app_readwrite;
GRANT app_readwrite TO app_owner;

DO
$$
BEGIN
    EXECUTE format('GRANT app_owner TO %I', CURRENT_USER);
END;
$$;

REVOKE ALL ON SCHEMA application FROM PUBLIC;
GRANT USAGE ON SCHEMA application TO app_readonly;
GRANT USAGE ON SCHEMA application TO app_readwrite;
GRANT USAGE, CREATE ON SCHEMA application TO app_owner;

ALTER ROLE app_readonly SET search_path = application, public;
ALTER ROLE app_readwrite SET search_path = application, public;
ALTER ROLE app_owner SET search_path = application, public;

ALTER SCHEMA application OWNER TO app_owner;
