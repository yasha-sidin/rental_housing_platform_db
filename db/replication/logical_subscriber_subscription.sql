\set ON_ERROR_STOP on

\if :{?publisher_host}
\else
    \echo 'publisher_host is required'
    \quit 1
\endif

\if :{?publisher_port}
\else
    \echo 'publisher_port is required'
    \quit 1
\endif

\if :{?publisher_db}
\else
    \echo 'publisher_db is required'
    \quit 1
\endif

\if :{?logical_replication_user}
\else
    \echo 'logical_replication_user is required'
    \quit 1
\endif

\if :{?logical_replication_password}
\else
    \echo 'logical_replication_password is required'
    \quit 1
\endif

SELECT NULLIF(:'publisher_host', '') IS NOT NULL AS publisher_host_is_set
\gset

\if :publisher_host_is_set
\else
    \echo 'publisher_host is required'
    \quit 1
\endif

SELECT NULLIF(:'publisher_port', '') IS NOT NULL AS publisher_port_is_set
\gset

\if :publisher_port_is_set
\else
    \echo 'publisher_port is required'
    \quit 1
\endif

SELECT NULLIF(:'publisher_db', '') IS NOT NULL AS publisher_db_is_set
\gset

\if :publisher_db_is_set
\else
    \echo 'publisher_db is required'
    \quit 1
\endif

SELECT NULLIF(:'logical_replication_user', '') IS NOT NULL AS logical_replication_user_is_set
\gset

\if :logical_replication_user_is_set
\else
    \echo 'logical_replication_user is required'
    \quit 1
\endif

SELECT NULLIF(:'logical_replication_password', '') IS NOT NULL AS logical_replication_password_is_set
\gset

\if :logical_replication_password_is_set
\else
    \echo 'logical_replication_password is required'
    \quit 1
\endif

WITH conninfo AS (
    SELECT format(
               'host=%s port=%s dbname=%s user=%s password=%s',
               :'publisher_host',
               :'publisher_port',
               :'publisher_db',
               :'logical_replication_user',
               :'logical_replication_password'
           ) AS value
)
SELECT format(
           'CREATE SUBSCRIPTION rental_currencies_subscription CONNECTION %L PUBLICATION rental_currencies_publication WITH (copy_data = true, create_slot = true, slot_name = ''rental_currencies_logical_slot'')',
           value
       )
FROM conninfo
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_subscription
    WHERE subname = 'rental_currencies_subscription'
)
\gexec

SELECT 'ALTER SUBSCRIPTION rental_currencies_subscription ENABLE'
WHERE EXISTS (
    SELECT 1
    FROM pg_subscription
    WHERE subname = 'rental_currencies_subscription'
)
\gexec
