-- 001__create_tablespaces.sql
--
-- Bootstrap табличных пространств PostgreSQL на уровне кластера.
--
-- Этот файл намеренно не является обычной прикладной миграцией:
-- CREATE TABLESPACE работает на уровне PostgreSQL-кластера, требует реальный
-- server-side путь в файловой системе и не может выполняться внутри transaction block.
--
-- Директории подготавливает кастомный PostgreSQL-контейнер до старта сервера:
--   /var/lib/postgresql/tablespaces/rental_reference
--   /var/lib/postgresql/tablespaces/rental_core
--   /var/lib/postgresql/tablespaces/rental_booking
--   /var/lib/postgresql/tablespaces/rental_history
--   /var/lib/postgresql/tablespaces/rental_index
--
-- Идемпотентность реализована через psql \gexec: SELECT генерирует CREATE TABLESPACE
-- только если tablespace еще не зарегистрирован в pg_tablespace.

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
