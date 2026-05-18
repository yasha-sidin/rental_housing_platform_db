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

В демонстрационном `.env.example` архивирование WAL выключено флагом `ENABLE_WAL_ARCHIVE=false`, чтобы базовый HA-стенд запускался без реального S3. Перед backup/PITR-сценарием нужно указать рабочие S3-настройки, выполнить `stanza-create`, затем включить `ENABLE_WAL_ARCHIVE=true` и пересоздать PostgreSQL-узлы.

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
