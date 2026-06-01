# Backup и PITR

## Выбранный подход

Для демонстрации используется:

```text
backup type: full
backup engine: pgBackRest
WAL archive: enabled
repository: S3-compatible object storage
restore drill: required
```

![Контур резервного копирования и PITR](diagrams/png/05_backup_pitr_contour.png)

В Docker-стенде роль S3-совместимого хранилища выполняет MinIO. Это демонстрационный компонент: он позволяет локально показать архив WAL, полную резервную копию и восстановление на момент времени. В production вместо него должен использоваться внешний S3-совместимый сервис с гарантиями доступности и долговечности данных.

Дифференциальные и инкрементальные backup остаются production-расширением, но не обязательны для защиты проекта.

## Надежность backup-процесса

Backup не запускается на каждой реплике. Это создало бы гонки, лишнюю нагрузку и сложность объяснения.

Вместо этого используется отдельный backup-контур:

```text
backup-worker-a
backup-worker-b
  -> общий lock
  -> выбор подходящей standby-реплики
  -> full backup
  -> repository check
```

Одновременно full backup запускает только один worker. Второй worker нужен для отказоустойчивости процесса.

## Источник backup

Приоритет источника:

```text
1. async replica
2. другая async replica
3. sync replica, если это не нарушает SLA
4. primary только вручную и явно
```

## WAL archive

WAL archive не должен зависеть от backup worker. PostgreSQL-узлы архивируют WAL в S3-compatible repository через pgBackRest.

После failover новый primary должен иметь тот же archive_command и доступ к тем же secrets.

В проекте архивирование WAL включено как часть базовой конфигурации кластера. Для локальной демонстрации используется MinIO из `docker-compose.yaml`, а `make up` подготавливает bucket и stanza pgBackRest. Отдельный флаг включения WAL-архива не нужен: если кластер запущен, backup-контур должен быть готов к работе.

## PITR

PITR используется для восстановления на момент времени до логической ошибки.

Демонстрационный сценарий:

```text
1. Full backup уже существует.
2. WAL archive включен.
3. Создается marker row.
4. Фиксируется restore point или timestamp.
5. Выполняется ошибочный DELETE.
6. Recovery-node восстанавливается до момента перед DELETE.
7. Marker row снова виден.
```
