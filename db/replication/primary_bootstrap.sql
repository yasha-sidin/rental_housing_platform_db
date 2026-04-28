\set ON_ERROR_STOP on

\if :{?physical_replication_password}
\else
    \echo 'physical_replication_password is required'
    \quit 1
\endif

\if :{?logical_replication_password}
\else
    \echo 'logical_replication_password is required'
    \quit 1
\endif

SELECT NULLIF(:'physical_replication_password', '') IS NOT NULL AS physical_replication_password_is_set
\gset

\if :physical_replication_password_is_set
\else
    \echo 'physical_replication_password is required'
    \quit 1
\endif

SELECT NULLIF(:'logical_replication_password', '') IS NOT NULL AS logical_replication_password_is_set
\gset

\if :logical_replication_password_is_set
\else
    \echo 'logical_replication_password is required'
    \quit 1
\endif

-- Роли репликации относятся к уровню PostgreSQL-кластера.
-- Поэтому они управляются infrastructure bootstrap, а не DDL-миграциями схемы application.
SELECT format(
           'CREATE ROLE physical_replicator WITH LOGIN REPLICATION PASSWORD %L',
           :'physical_replication_password'
       )
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = 'physical_replicator'
)
\gexec

ALTER ROLE physical_replicator
    WITH LOGIN REPLICATION PASSWORD :'physical_replication_password';

SELECT format(
           'CREATE ROLE logical_replicator WITH LOGIN REPLICATION PASSWORD %L',
           :'logical_replication_password'
       )
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = 'logical_replicator'
)
\gexec

ALTER ROLE logical_replicator
    WITH LOGIN REPLICATION PASSWORD :'logical_replication_password';

GRANT USAGE ON SCHEMA application TO logical_replicator;
GRANT SELECT ON application.currencies TO logical_replicator;

-- Physical slots удерживают WAL, который еще нужен двум physical standby.
SELECT pg_create_physical_replication_slot('rental_physical_fast_slot')
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_replication_slots
    WHERE slot_name = 'rental_physical_fast_slot'
);

SELECT pg_create_physical_replication_slot('rental_physical_delayed_slot')
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_replication_slots
    WHERE slot_name = 'rental_physical_delayed_slot'
);

-- Logical publication отдает subscriber только один стабильный справочник.
SELECT 'CREATE PUBLICATION rental_currencies_publication FOR TABLE application.currencies'
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_publication
    WHERE pubname = 'rental_currencies_publication'
)
\gexec

ALTER PUBLICATION rental_currencies_publication
    SET TABLE application.currencies;
