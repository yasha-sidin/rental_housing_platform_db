# Физическая репликация PostgreSQL

## Назначение

Физическая репликация в проекте построена как streaming replication всего PostgreSQL-кластера. Реплики получают WAL с primary и воспроизводят изменения на уровне страниц данных, поэтому содержат тот же набор баз, схем, таблиц, индексов, ролей и табличных пространств, что и primary.

В стенде используются две physical standby-реплики:

- `rental_housing_platform_db_physical_fast` - обычная асинхронная read-only реплика без искусственной задержки;
- `rental_housing_platform_db_physical_delayed` - асинхронная read-only реплика с задержкой применения WAL на 5 минут.

Primary остается существующий контейнер `rental_housing_platform_db`; его данные не пересоздаются при запуске replication profile.

## Топология

| Роль | Compose service | Порт хоста | Слот | Конфиг |
| --- | --- | --- | --- | --- |
| Primary | `rental_housing_platform_db` | `5488` | - | `docker/postgres/conf/primary/postgresql.conf` |
| Fast physical standby | `rental_housing_platform_db_physical_fast` | `5489` | `rental_physical_fast_slot` | `docker/postgres/conf/physical-fast/postgresql.conf` |
| Delayed physical standby | `rental_housing_platform_db_physical_delayed` | `5490` | `rental_physical_delayed_slot` | `docker/postgres/conf/physical-delayed/postgresql.conf` |

Каждая physical-реплика получает собственные Docker volumes для `PGDATA` и для всех путей tablespaces. Это важно: physical standby хранит бинарную копию кластера и не должна писать в те же volume, что и primary.

## Настройки primary

Primary получает replication-настройки через volume:

```text
./docker/postgres/conf/primary:/etc/postgresql/primary:ro
```

Ключевые параметры:

- `wal_level = logical` - уровень WAL достаточен и для физической, и для логической репликации;
- `max_wal_senders = 10` - разрешает replication-подключения;
- `max_replication_slots = 10` - разрешает physical и logical slots;
- `hba_file = '/etc/postgresql/primary/pg_hba.conf'` - явно подключает проектный `pg_hba.conf`.

`pg_hba.conf` разрешает:

- обычные клиентские подключения;
- physical replication для роли `physical_replicator`;
- logical replication connection для роли `logical_replicator`.

Пароли replication-ролей не имеют fallback-значений в репозитории. Они должны быть заданы в локальном `.env`:

```env
PHYSICAL_REPLICATION_PASSWORD=
LOGICAL_REPLICATION_PASSWORD=
```

Если переменные не заданы или пустые, entrypoint реплики и SQL bootstrap останавливаются с явной ошибкой.

## Слоты репликации

Слоты создаются скриптом `db/replication/primary_bootstrap.sql`:

- `rental_physical_fast_slot`;
- `rental_physical_delayed_slot`.

Replication slot фиксирует, какой WAL еще нужен конкретной реплике. Primary не удаляет WAL, пока реплика его не получит. Это защищает реплику от разрыва, но создает эксплуатационный риск: если реплика долго выключена, WAL на primary может расти. Поэтому слоты нужно мониторить через `pg_replication_slots`.

## Инициализация реплик

Physical standby запускается через `docker/postgres/replica_entrypoint.sh`.

При первом старте, если в `$PGDATA` нет `PG_VERSION`, entrypoint:

- проверяет обязательные переменные окружения;
- очищает собственные tablespace volumes реплики;
- ждет готовности primary;
- выполняет `pg_basebackup` из primary;
- создает `standby.signal`;
- записывает `primary_conninfo` в `postgresql.auto.conf`;
- запускает PostgreSQL с конфигом реплики.

Если `$PGDATA/PG_VERSION` уже существует, повторный `pg_basebackup` не выполняется: реплика стартует из сохраненного volume.

## Быстрая реплика

`physical-fast` использует:

```conf
primary_slot_name = 'rental_physical_fast_slot'
hot_standby = on
```

Она подходит для:

- read-only запросов, которые не должны нагружать primary;
- быстрых аналитических выборок по актуальным данным;
- проверки, что WAL streaming работает без искусственной задержки;
- потенциальной основы для failover-сценария.

Реплика асинхронная: primary не ждет подтверждения записи от standby перед commit.

## Delayed-реплика

`physical-delayed` использует:

```conf
primary_slot_name = 'rental_physical_delayed_slot'
hot_standby = on
recovery_min_apply_delay = '5min'
```

Она получает WAL сразу, но применяет commit не раньше чем через 5 минут. Это полезно для защиты от логических ошибок:

- случайный `DELETE` или `UPDATE`;
- ошибочная миграция;
- массовая порча данных приложением;
- необходимость быстро посмотреть состояние данных до недавнего инцидента.

Delayed standby не является хорошей целью для немедленного failover: по смыслу она специально отстает от primary.

## Запуск

```bash
make replication-up
```

Команда:

- поднимает primary;
- создает или обновляет replication-роли;
- создает physical slots;
- запускает physical replicas и logical subscriber;
- создает logical subscription.

Остановить только replication-контейнеры без удаления volumes:

```bash
make replication-down
```

## Проверка

Проверить, что контейнеры подняты:

```bash
make replication-ps
```

Проверить, что конфиги реально применились:

```bash
make replication-config-check
```

Проверить состояние physical streaming replication:

```bash
make replication-physical-status
```

Ключевые признаки корректного состояния:

- в `pg_stat_replication` есть `physical_fast` и `physical_delayed`;
- оба подключения находятся в состоянии `streaming`;
- в `pg_replication_slots` physical slots активны;
- на standby `pg_is_in_recovery()` возвращает `true`;
- у delayed standby `recovery_min_apply_delay` равен `5min`;
- `pg_file_settings.applied = true` для файлов из `/etc/postgresql/...`.

## Артефакты проверки

Выводы команд сохраняются в `artifacts/replication/`:

- `primary_config.txt` - примененные настройки primary и `pg_hba`;
- `primary_replication_status.txt` - `pg_stat_replication`, replication slots и publication;
- `physical_fast_status.txt` - состояние fast standby;
- `physical_delayed_status.txt` - состояние delayed standby;
- `physical_insert_primary.txt` - вставка проверочной строки в primary;
- `physical_fast_after_insert.txt` - fast standby видит проверочную строку почти сразу;
- `physical_delayed_before_delay.txt` - delayed standby еще не видит строку до истечения задержки;
- `physical_delayed_after_delay.txt` - delayed standby видит строку после 5-минутной задержки.

Сценарий фиксации отставания:

```bash
make replication-capture-physical-delay
```

Он вставляет проверочную валюту `XPH`, ждет 10 секунд, фиксирует состояние fast и delayed standby, затем ждет 310 секунд и повторно фиксирует delayed standby.
