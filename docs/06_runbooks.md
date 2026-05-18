# Runbooks

## Отказ primary

1. Зафиксировать текущее состояние `docker compose ps`.
2. Определить current primary через Patroni REST API или SQL `pg_is_in_recovery()`.
3. Остановить контейнер primary.
4. Дождаться promotion новой реплики.
5. Проверить HAProxy writer endpoint.
6. Выполнить тестовую запись.
7. Сохранить вывод в `demo/03-failover/artifacts/`.

## Потеря synchronous replicas

1. Остановить одну synchronous replica и проверить, что запись еще доступна.
2. Остановить еще одну нужную synchronous replica.
3. Показать, что запись останавливается.
4. Объяснить, что это защита `RPO = 0`.
5. Сохранить вывод в `demo/05-sync-rpo-zero/artifacts/`.

## Отказ client-local proxy

1. Остановить `pgbouncer-client-a`.
2. Показать, что клиент A не работает.
3. Показать, что клиент B продолжает выполнять SQL через свой PgBouncer.
4. Сохранить вывод в `demo/04-proxy-failure/artifacts/`.

## Логическая ошибка

1. Подготовить full backup и WAL archive.
2. Создать marker row.
3. Зафиксировать restore point или timestamp.
4. Выполнить ошибочный `DELETE`.
5. Показать, что ошибка видна на кластере.
6. Восстановить recovery-node через PITR.
7. Сохранить проверочный SELECT в `demo/07-pitr/artifacts/`.

## Деградация backup worker

1. Остановить активный backup worker.
2. Запустить backup вторым worker.
3. Проверить repository.
4. Сохранить вывод `pgbackrest info/check`.
