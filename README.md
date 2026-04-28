# Rental Housing Platform DB

## О проекте

Учебный проект по проектированию реляционной базы данных для платформы краткосрочной аренды жилья.

Цель: спроектировать устойчивую к аномалиям модель данных, которая покрывает ключевые доменные области:

- пользователи;
- объекты недвижимости;
- календарь доступности;
- ценообразование и история цен;
- бронирования;
- платежи;
- отзывы и рейтинги.

Проект сфокусирован на уровне БД: схема, ограничения целостности, миграции, тестовые данные и SQL-запросы для операционных и аналитических задач.

## Структура проекта

```text
rental_housing_platform_db/
+- docker-compose.yaml
+- Makefile
+- .env
+- README.md
+- docker/
¦  +- postgres/
¦  ¦  +- Dockerfile
¦  ¦  L- ensure_tablespaces.sh
¦  L- migrations/
¦     +- Dockerfile
¦     +- prepare_migrations.sh
¦     L- run_migrate.sh
+- docs/
¦  +- 00_technical_specification.md
¦  +- 01_context.md
¦  +- 02_domain_model.md
¦  +- 03_invariants.md
¦  +- 04_business_tasks_catalog.md
¦  +- 05_indexes.md
¦  L- erd/
+- db/
¦  +- bootstrap/
¦  +- migrations/
¦  +- rollback/
¦  +- seeds/
¦  L- tests/
+- sql/
¦  +- operational/
¦  L- analytics/
L- artifacts/
   +- explain/
   L- snapshots/
```

## Система миграций (Docker-only)

Миграции выполняются только через отдельный контейнер `migration_runner` и `golang-migrate`.

Перед применением миграций выполняется cluster-level bootstrap табличных пространств:

- кастомный PostgreSQL-контейнер из `docker/postgres/` при старте проверяет и создает директории для tablespaces;
- каждый tablespace смонтирован отдельным Docker named volume, что моделирует раздельные физические диски;
- `db/bootstrap/001__create_tablespaces.sql` идемпотентно создает tablespaces, если их еще нет;
- `V011__assign_application_tablespaces.sql` распределяет таблицы и индексы схемы `application` по tablespaces.

Bootstrap отделен от обычных миграций, потому что `CREATE TABLESPACE` работает на уровне PostgreSQL-кластера, требует существующий путь на сервере БД и не выполняется внутри transaction block.

Важно:

- исходные файлы в репозитории не переименовываются:
  - up-миграции: `db/migrations/V...sql`;
  - down-миграции: `db/rollback/U...sql`;
- перед запуском утилиты внутри контейнера они конвертируются во временный формат `*.up.sql` / `*.down.sql`;
- состояние версий хранится в стандартной таблице `schema_migrations`, которую ведет `golang-migrate`;
- `schema_migrations` остается служебной таблицей migration tool и не переносится в прикладную схему `application`.

## Команды Makefile

### Базовые

- `make up` - поднять PostgreSQL контейнер.
- `make down` - остановить контейнеры.
- `make restart` - перезапуск PostgreSQL.
- `make logs` - логи PostgreSQL.
- `make ps` - список сервисов.
- `make db-wait` - дождаться готовности PostgreSQL к подключениям.
- `make bootstrap-tablespaces` - создать PostgreSQL tablespaces, если они еще не созданы.

### Миграции

- `make migrate-check` - проверить парность `V/U` без применения миграций.
- `make migrate-up` - поднять PostgreSQL, выполнить bootstrap tablespaces и применить все pending миграции.
- `make migrate-down-one` - откатить одну миграцию.
- `make migrate-down STEPS=N` - откатить `N` миграций.
- `make migrate-version` - показать текущую версию миграций.
- `make migrate-goto VERSION=N` - перейти к целевой версии.
- `make migrate-force VERSION=N` - принудительно установить версию (аварийная операция).
### Сиды (тестовые данные)

- `make seed-run` - загрузить базовые сиды (`001..003`).
- `make seed-load N=1000` - загрузить массовые данные (по умолчанию `N=1000`, максимум `N=100000`).
- `make seed-clean` - очистить все данные, добавленные seed-скриптами (миграционные таблицы не затрагиваются).
- `make seed-reset` - пересоздать БД, применить миграции и загрузить базовые сиды.

`seed-load` расширяет нагрузку сразу на несколько таблиц:
`users`, `user_roles`, `addresses`, `listings`, `photos`, `listing_photos`, `base_prices`,
`listing_availability_days`, `price_history`.

### SQL-запросы

- `make dml-run FILE=sql/analytics/select_regex.sql` - запустить один SQL-файл из каталога `sql/` внутри PostgreSQL-контейнера.

SQL-сценарии проекта сгруппированы по назначению:

- `sql/analytics/` - аналитические выборки, отчеты, COPY-выгрузки и EXPLAIN;
- `sql/operational/` - операционные сценарии изменения данных.

## Где что хранится

- `docker-compose.yaml` - локальный запуск PostgreSQL и migration-runner.
- `Makefile` - единая точка входа для запуска БД и миграций.
- `docker/postgres/` - кастомный PostgreSQL-образ, который готовит директории tablespaces перед стартом БД.
- `docker/migrations/` - Dockerfile и скрипты контейнера миграций.
- `db/bootstrap/` - cluster-level SQL bootstrap для объектов, которые не являются обычными миграциями приложения.
- `.env` - параметры окружения для контейнеров.
- `docs/` - текстовая документация проекта.
- `docs/00_technical_specification.md` - полная версия технического задания (единый источник требований).
- `docs/01_context.md` - краткий рабочий контекст проекта и навигация по артефактам.
- `docs/02_domain_model.md` - сущности, атрибуты и связи доменной модели.
- `docs/03_invariants.md` - бизнес-инварианты, обеспечиваемые на уровне БД.
- `docs/04_business_tasks_catalog.md` - каталог бизнес-задач.
- `docs/05_indexes.md` - индексы, сценарии их использования и анализ планов выполнения.
- `docs/erd/` - ER-диаграмма (исходники и экспорт).
- `db/migrations/` - DDL up-миграции в исходном формате проекта.
- `db/rollback/` - DDL down-миграции в исходном формате проекта.
- `db/seeds/` - заполнение справочников и тестовых данных.
- `db/tests/` - SQL-проверки ограничений и инвариантов.
- `sql/operational/` - операционные SQL-запросы для изменения данных.
- `sql/analytics/` - аналитические SQL-запросы, отчеты, COPY-выгрузки и планы выполнения.
- `artifacts/explain/` - планы выполнения (`EXPLAIN`) ключевых запросов.
- `artifacts/snapshots/` - снимки результатов для отчета/защиты.

## Принцип работы с репозиторием

- Все изменения схемы вносятся только через `db/migrations/` и `db/rollback/`.
- Миграции запускаются только через `Makefile`.
- Тестовые данные добавляются через `db/seeds/`.
- Проверки бизнес-правил фиксируются в `db/tests/`.
- Основные требования ведутся в `docs/00_technical_specification.md`.
- Документация синхронизируется с фактической схемой БД.
