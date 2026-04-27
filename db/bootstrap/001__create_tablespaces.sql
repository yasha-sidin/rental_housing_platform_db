-- 001__create_tablespaces.sql
--
-- Cluster-level bootstrap for PostgreSQL tablespaces.
--
-- This file is intentionally not a normal application migration:
-- CREATE TABLESPACE works at PostgreSQL cluster level, requires a real server-side
-- filesystem path, and cannot run inside a transaction block.
--
-- Directories are prepared by the custom PostgreSQL container before server start:
--   /var/lib/postgresql/tablespaces/rental_reference
--   /var/lib/postgresql/tablespaces/rental_core
--   /var/lib/postgresql/tablespaces/rental_booking
--   /var/lib/postgresql/tablespaces/rental_history
--   /var/lib/postgresql/tablespaces/rental_index
--
-- Idempotency is implemented with psql \gexec: the SELECT emits CREATE TABLESPACE
-- only if the tablespace is not already registered in pg_tablespace.

\echo Creating PostgreSQL tablespaces when they are missing

SELECT format(
           'CREATE TABLESPACE %I LOCATION %L',
           'rental_reference_ts',
           '/var/lib/postgresql/tablespaces/rental_reference'
       )
WHERE NOT EXISTS (
    SELECT 1 FROM pg_tablespace WHERE spcname = 'rental_reference_ts'
)
\gexec

SELECT format(
           'CREATE TABLESPACE %I LOCATION %L',
           'rental_core_ts',
           '/var/lib/postgresql/tablespaces/rental_core'
       )
WHERE NOT EXISTS (
    SELECT 1 FROM pg_tablespace WHERE spcname = 'rental_core_ts'
)
\gexec

SELECT format(
           'CREATE TABLESPACE %I LOCATION %L',
           'rental_booking_ts',
           '/var/lib/postgresql/tablespaces/rental_booking'
       )
WHERE NOT EXISTS (
    SELECT 1 FROM pg_tablespace WHERE spcname = 'rental_booking_ts'
)
\gexec

SELECT format(
           'CREATE TABLESPACE %I LOCATION %L',
           'rental_history_ts',
           '/var/lib/postgresql/tablespaces/rental_history'
       )
WHERE NOT EXISTS (
    SELECT 1 FROM pg_tablespace WHERE spcname = 'rental_history_ts'
)
\gexec

SELECT format(
           'CREATE TABLESPACE %I LOCATION %L',
           'rental_index_ts',
           '/var/lib/postgresql/tablespaces/rental_index'
       )
WHERE NOT EXISTS (
    SELECT 1 FROM pg_tablespace WHERE spcname = 'rental_index_ts'
)
\gexec

\echo Registered project tablespaces
SELECT spcname AS tablespace_name,
       pg_tablespace_location(oid) AS location
FROM pg_tablespace
WHERE spcname IN (
    'rental_reference_ts',
    'rental_core_ts',
    'rental_booking_ts',
    'rental_history_ts',
    'rental_index_ts'
)
ORDER BY spcname;
