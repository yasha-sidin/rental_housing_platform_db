# Построение отказоустойчивого PostgreSQL-кластера для платформы краткосрочной аренды жилья

Проект выполняется в рамках курса OTUS **"Базы данных"**. Цель проекта - показать не только доменную схему базы данных, но и инженерный контур высокой доступности для PostgreSQL: автоматический failover, синхронную репликацию с `RPO = 0`, резервное копирование, WAL archive и point-in-time recovery.

## Что строится

Предметная область - платформа краткосрочной аренды жилья:

- пользователи, роли и права;
- объявления и фотографии жилья;
- адреса, города, страны и валюты;
- календарь доступности;
- цены и история изменения цен;
- бронирования, платежи и отзывы.

Инфраструктурная часть проекта:

- 5 PostgreSQL/Patroni-узлов;
- 5 etcd-узлов для quorum и leader lock Patroni;
- режим `1 primary + минимум 2 synchronous replicas`;
- client-local PgBouncer + HAProxy для двух демонстрационных клиентов;
- отдельный migration runner, который применяет миграции через writer endpoint;
- два backup worker без единой точки отказа процесса backup;
- pgBackRest, full backup, WAL archive и PITR;
- S3-compatible repository как внешний надежный backup backend;
- PMM как визуальный контур наблюдаемости.

Контур высокой доступности - часть архитектуры, отвечающая за непрерывную работу базы данных при отказе отдельных узлов.

## Архитектура

Логическая топология стенда:

```text
client-a -> PgBouncer -> HAProxy writer/read -> PostgreSQL/Patroni cluster
client-b -> PgBouncer -> HAProxy writer/read -> PostgreSQL/Patroni cluster

PostgreSQL/Patroni:
  postgres-node-1
  postgres-node-2
  postgres-node-3
  postgres-node-4
  postgres-node-5

etcd quorum:
  etcd-1
  etcd-2
  etcd-3
  etcd-4
  etcd-5

backup:
  backup-worker-a
  backup-worker-b
  S3-compatible repository

observability:
  PMM Server
```

Для 5 узлов etcd quorum равен 3. Это позволяет пережить отказ двух etcd-узлов. Для PostgreSQL включается строгий режим синхронной репликации: запись подтверждается клиенту только после попадания WAL на primary и минимум две synchronous replicas.

## RPO, RTO и PITR

`RPO = 0` в проекте означает: подтвержденные клиенту транзакции не теряются при отказе primary, если в момент записи доступны две synchronous replicas.

Если синхронных реплик становится меньше двух, запись должна остановиться. Это ожидаемый защитный режим: кластер временно теряет возможность принимать записи, но не нарушает обещание `RPO = 0`.

`RTO` - время восстановления. В проекте отдельно измеряются:

- RTO automatic failover;
- RTO восстановления из full backup;
- RTO PITR на recovery-node.

PITR защищает от логических ошибок: ошибочный `DELETE`, `UPDATE`, `DROP` или плохая миграция будут реплицированы на все узлы, поэтому для восстановления нужен full backup + WAL archive + восстановление на момент времени до ошибки.

## Миграции

Миграции переписаны как компактная цепочка без tablespaces:

```text
db/migrations/V001__database_baseline.sql
db/migrations/V002__reference_catalogs.sql
db/migrations/V003__users_listings_photos.sql
db/migrations/V004__pricing_availability.sql
db/migrations/V005__bookings_payments_reviews.sql
db/migrations/V006__indexes_comments_grants.sql
```

Обратные миграции лежат в `db/rollback/`.

Миграции применяются вручную после поднятия кластера и proxy-контура:

```text
migration_runner -> HAProxy writer endpoint -> current primary
```

Мигратор по умолчанию обходит PgBouncer. Если PgBouncer используется для миграций, для него должен быть отдельный endpoint в `session pooling` mode.

## Клиентское чтение

Проект демонстрирует два режима чтения на стороне клиента:

```text
normal session
  write -> writer endpoint -> current primary
  read  -> reader endpoint -> replica pool

strong session
  write -> writer endpoint -> current primary
  read  -> writer endpoint -> current primary
```

`normal` подходит для сценариев, где допустима eventual consistency. `strong` используется там, где нужна гарантия read-after-write.

## Backup

Для демонстрации используется только full backup. WAL archive включен отдельно, потому что именно он нужен для PITR.
В базовом `.env.example` `ENABLE_WAL_ARCHIVE=false`, чтобы HA-стенд запускался без реального S3. Для backup/PITR-сценариев нужно указать рабочий S3-compatible endpoint, выполнить `stanza-create` и включить `ENABLE_WAL_ARCHIVE=true`.

Надежность backup-процесса достигается не запуском backup на каждой реплике, а отдельным backup-контуром:

```text
backup-worker-a
backup-worker-b
  -> lock
  -> выбор подходящей standby-реплики
  -> pgBackRest full backup
  -> repository check
  -> restore drill
```

S3-compatible repository считается внешним высокодоступным хранилищем. Docker-стенд не имитирует production-grade S3 несколькими MinIO-контейнерами.

## Команды

Публичный интерфейс Makefile намеренно короткий:

```text
make up
make clear
make verify
make demo SCENARIO=<name>
make down
```

Makefile является тонкой оберткой над единым Cobra CLI и запускает готовый бинарник из `bin/`. Для обычного запуска проекта Go на машине не нужен.

Исполняемые файлы:

```text
bin/rentalctl.exe
bin/rentalctl-linux-amd64
bin/rentalctl-darwin-amd64
bin/rentalctl-darwin-arm64
```

Исходники CLI остаются в `cmd/rentalctl/` и `internal/`, но они нужны только для разработки самого инструмента.

Назначение:

- `make up` - поднять демонстрационный стенд;
- `make clear` - очистить прикладные и демонстрационные данные без удаления контейнеров и volumes;
- `make verify` - проверить базовую готовность ключевых подсистем;
- `make demo SCENARIO=<name>` - запустить выбранный демонстрационный сценарий;
- `make down` - полностью удалить стенд, volumes и временное состояние.

Сценарии:

```text
SCENARIO=domain
SCENARIO=migration
SCENARIO=failover
SCENARIO=proxy
SCENARIO=rpo-zero
SCENARIO=backup
SCENARIO=pitr
SCENARIO=observability
```

## Требования к стенду

Минимально:

```text
CPU: 6 cores
RAM: 24 GB
Disk: 50 GB free
OS:
  - Windows 10/11 + Docker Desktop + WSL2
  - Linux x86_64 + Docker Engine + Docker Compose v2
  - macOS 13+ + Docker Desktop
Docker: required
```

Рекомендуемо:

```text
CPU: 6-8 cores
RAM: 32 GB
Disk: 80+ GB free
Docker: required
```

Для Windows предпочтителен backend WSL2. Для macOS нужно заранее выделить Docker Desktop достаточный лимит CPU/RAM. Для Linux достаточно Docker Engine и Compose plugin.

## Документация

- `docs/00_project_brief.md` - цель и границы проекта.
- `docs/01_domain_model.md` - доменная модель.
- `docs/02_schema_design.md` - схема БД, миграции и инварианты.
- `docs/03_cluster_topology.md` - Patroni, etcd, PgBouncer, HAProxy, PMM.
- `docs/04_rpo_rto.md` - RPO/RTO и границы гарантий.
- `docs/05_backup_pitr.md` - backup workers, pgBackRest, WAL archive, PITR.
- `docs/06_runbooks.md` - действия при отказах.
- `docs/07_demo_plan.md` - сценарии защиты.
- `docs/08_production_requirements.md` - требования к production-системе.
- `docs/09_sources.md` - источники и документация инструментов.
- `docs/adr/` - архитектурные решения.

## Визуальные материалы

Новые схемы топологий должны храниться в `docs/diagrams/png/`. Старые screenshots и подтверждения из предыдущей версии проекта не используются: новые подтверждения создаются после реализации demo-сценариев и сохраняются рядом со сценариями в `demo/*/artifacts/`.
