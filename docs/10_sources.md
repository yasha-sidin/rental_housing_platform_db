# Источники

В проекте использовались официальные руководства и документация инструментов, примененных в архитектуре PostgreSQL-кластера высокой доступности.

## PostgreSQL

- Документация PostgreSQL по высокой доступности, балансировке нагрузки и репликации: https://www.postgresql.org/docs/current/high-availability.html
- Примечания к выпускам PostgreSQL: https://www.postgresql.org/docs/release/

## Управление кластером и согласование состояния

- Документация Patroni: https://patroni.readthedocs.io/
- Документация Patroni REST API: https://patroni.readthedocs.io/en/latest/rest_api.html
- Документация etcd: https://etcd.io/docs/

## Резервное копирование и восстановление

- Руководство пользователя pgBackRest: https://pgbackrest.org/user-guide.html
- Документация MinIO: https://min.io/docs/
- Документация Barman: https://www.enterprisedb.com/docs/supported-open-source/barman/
- Документация WAL-G для PostgreSQL: https://wal-g.readthedocs.io/PostgreSQL/

## Клиентская маршрутизация и пул соединений

- Документация PgBouncer: https://www.pgbouncer.org/usage.html
- Документация HAProxy: https://www.haproxy.com/documentation/

## Наблюдаемость

- Документация Percona Monitoring and Management: https://docs.percona.com/percona-monitoring-and-management/

## Операторы PostgreSQL и практики резервного копирования

- Документация Percona Operator for PostgreSQL по резервному копированию: https://docs.percona.com/percona-operator-for-postgresql/2.9.0/backups.html
- Документация Crunchy Postgres for Kubernetes по резервному копированию и восстановлению: https://access.crunchydata.com/documentation/postgres-operator/latest/tutorials/backups-disaster-recovery/backups
- Документация CloudNativePG по резервному копированию в объектные хранилища: https://cloudnative-pg.io/docs/1.29/appendixes/backup_barmanobjectstore/
