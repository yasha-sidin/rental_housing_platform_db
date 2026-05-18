# Demo Plan

## 01-domain

Показать схему, seed-данные и проверки инвариантов.

Артефакты:

- counts по основным таблицам;
- вывод SQL-проверок из `db/tests/`.

## 02-migration

Показать применение миграций через writer endpoint.

Артефакты:

- версия миграций;
- список примененных миграций;
- подтверждение, что endpoint ведет на primary.

## 03-failover

Показать automatic failover после остановки primary.

Артефакты:

- состояние до аварии;
- остановка primary;
- новый primary;
- успешная запись после failover;
- measured RTO.

## 04-proxy-failure

Показать, что отказ PgBouncer одного клиента не ломает второго клиента.

## 05-sync-rpo-zero

Показать сохранность подтвержденной транзакции и остановку записи при нехватке synchronous replicas.

## 06-backup

Показать full backup, `pgbackrest info` и `pgbackrest check`.

## 07-pitr

Показать восстановление recovery-node до момента перед логической ошибкой.

## 08-observability

Показать PMM dashboard и HAProxy stats.
