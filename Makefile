# Используем POSIX shell для всех рецептов Makefile,
# чтобы команды одинаково работали в Linux-контейнерной среде.
SHELL := /bin/sh

# Базовая команда docker compose.
COMPOSE := docker compose

# Шаблон запуска одноразового контейнера миграций.
# --rm удаляет контейнер после выполнения команды.
MIGRATE_RUNNER := $(COMPOSE) run --rm migration_runner
MIGRATE_RUNNER_NO_DEPS := $(COMPOSE) run --rm --no-deps migration_runner

# Сервисы репликационного стенда.
REPLICATION_SERVICES := rental_housing_platform_db_physical_fast rental_housing_platform_db_physical_delayed rental_housing_platform_db_logical_subscriber

# Количество строк для нагрузочного сида по умолчанию.
N ?= 1000

# Список целей, которые не являются именами файлов.
.PHONY: up down restart logs ps db-shell db-wait bootstrap-tablespaces migrate-check migrate-up migrate-down-one migrate-down migrate-version migrate-force migrate-goto seed-run seed-load seed-clean seed-reset dml-run replication-up replication-down replication-ps replication-logs replication-wait replication-bootstrap-primary replication-bootstrap-logical replication-config-check replication-physical-status replication-logical-status replication-capture replication-capture-logical-demo replication-capture-physical-delay

# Поднять только PostgreSQL-сервис в фоне.
up:
	$(COMPOSE) up -d rental_housing_platform_db

# Остановить и удалить контейнеры/сеть проекта.
down:
	$(COMPOSE) down

# Полный перезапуск PostgreSQL.
restart: down up

# Смотреть логи PostgreSQL в реальном времени.
logs:
	$(COMPOSE) logs -f rental_housing_platform_db

# Показать текущее состояние сервисов compose.
ps:
	$(COMPOSE) ps

db-wait: up
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'until pg_isready -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"; do sleep 1; done'

# Открыть psql внутри контейнера БД.
# Переменные POSTGRES_USER/POSTGRES_DB берутся из env контейнера.
db-shell:
	$(COMPOSE) exec rental_housing_platform_db sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

bootstrap-tablespaces: db-wait
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'psql -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/db/bootstrap/001__create_tablespaces.sql'

# Проверка парности и корректности формата V/U миграций
# без применения изменений в БД.
migrate-check:
	$(MIGRATE_RUNNER_NO_DEPS) /app/prepare_migrations.sh --check-only

# Применить все pending миграции вверх.
migrate-up: bootstrap-tablespaces
	$(MIGRATE_RUNNER) /app/run_migrate.sh up

# Откатить ровно одну миграцию вниз.
migrate-down-one:
	$(MIGRATE_RUNNER) /app/run_migrate.sh down 1

# Откатить указанное количество миграций вниз.
# Пример: make migrate-down STEPS=3
migrate-down:
ifndef STEPS
	$(error STEPS is required, example: make migrate-down STEPS=3)
endif
	$(MIGRATE_RUNNER) /app/run_migrate.sh down $(STEPS)

# Показать текущую версию миграций (и dirty-статус, если есть).
migrate-version:
	$(MIGRATE_RUNNER) /app/run_migrate.sh version

# Аварийно установить версию без выполнения SQL.
# Использовать только при восстановлении после ошибки/dirty.
# Пример: make migrate-force VERSION=8
migrate-force:
ifndef VERSION
	$(error VERSION is required, example: make migrate-force VERSION=8)
endif
	$(MIGRATE_RUNNER) /app/run_migrate.sh force $(VERSION)

# Перейти к целевой версии (вверх/вниз, в зависимости от текущей).
# Пример: make migrate-goto VERSION=8
migrate-goto:
ifndef VERSION
	$(error VERSION is required, example: make migrate-goto VERSION=8)
endif
	$(MIGRATE_RUNNER) /app/run_migrate.sh goto $(VERSION)

# Прогон базовых сидов в детерминированном порядке.
seed-run: db-wait
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'PGOPTIONS="-c search_path=application,public" psql -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/db/seeds/001_reference.sql'
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'PGOPTIONS="-c search_path=application,public" psql -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/db/seeds/002_base_entities.sql'
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'PGOPTIONS="-c search_path=application,public" psql -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/db/seeds/003_scenarios.sql'

# Нагрузочный сид. По умолчанию N=1000, можно переопределить:
# make seed-load N=5000
seed-load:
	@powershell -NoProfile -Command "if ([int]'$(N)' -gt 100000) { Write-Error 'N=$(N) is too large for local run. Max allowed is 100000.'; exit 1 }"
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'PGOPTIONS="-c search_path=application,public" psql -v ON_ERROR_STOP=1 -v rows=$(N) -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/db/seeds/004_load.sql'

# Очистка load-данных.
seed-clean:
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'PGOPTIONS="-c search_path=application,public" psql -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/db/seeds/999_cleanup.sql'

# Запустить один SQL-файл из каталога sql/ внутри PostgreSQL-контейнера.
dml-run: db-wait
ifndef FILE
	$(error FILE is required, example: make dml-run FILE=sql/analytics/select_regex.sql)
endif
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'PGOPTIONS="-c search_path=application,public" psql -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/$(FILE)'

# Поднять primary, подготовить роли/slots/publication и запустить реплики.
replication-up:
	$(COMPOSE) up -d --build rental_housing_platform_db
	$(MAKE) db-wait
	$(MAKE) replication-bootstrap-primary
	$(COMPOSE) --profile replication up -d --build $(REPLICATION_SERVICES)
	$(MAKE) replication-wait
	$(MAKE) replication-bootstrap-logical

# Остановить контейнеры репликационного стенда, не удаляя volumes.
replication-down:
	$(COMPOSE) --profile replication stop $(REPLICATION_SERVICES)
	$(COMPOSE) --profile replication rm -f $(REPLICATION_SERVICES)

replication-ps:
	$(COMPOSE) --profile replication ps

replication-logs:
	$(COMPOSE) --profile replication logs -f $(REPLICATION_SERVICES)

replication-wait:
	$(COMPOSE) exec -T rental_housing_platform_db_physical_fast sh -c 'until pg_isready -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"; do sleep 1; done'
	$(COMPOSE) exec -T rental_housing_platform_db_physical_delayed sh -c 'until pg_isready -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"; do sleep 1; done'
	$(COMPOSE) exec -T rental_housing_platform_db_logical_subscriber sh -c 'until pg_isready -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"; do sleep 1; done'

replication-bootstrap-primary: db-wait
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'psql -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -v physical_replication_password="$$PHYSICAL_REPLICATION_PASSWORD" -v logical_replication_password="$$LOGICAL_REPLICATION_PASSWORD" -f /workspace/db/replication/primary_bootstrap.sql'

replication-bootstrap-logical:
	$(COMPOSE) exec -T rental_housing_platform_db_logical_subscriber sh -c 'psql -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/db/replication/logical_subscriber_schema.sql'
	$(COMPOSE) exec -T rental_housing_platform_db_logical_subscriber sh -c 'psql -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -v publisher_host="$$PUBLISHER_HOST" -v publisher_port="$$PUBLISHER_PORT" -v publisher_db="$$POSTGRES_DB" -v logical_replication_user="$$LOGICAL_REPLICATION_USER" -v logical_replication_password="$$LOGICAL_REPLICATION_PASSWORD" -f /workspace/db/replication/logical_subscriber_subscription.sql'

replication-config-check:
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'psql -P pager=off -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_primary_config.sql'
	$(COMPOSE) exec -T rental_housing_platform_db_physical_fast sh -c 'psql -P pager=off -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_physical_replica.sql'
	$(COMPOSE) exec -T rental_housing_platform_db_physical_delayed sh -c 'psql -P pager=off -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_physical_replica.sql'
	$(COMPOSE) exec -T rental_housing_platform_db_logical_subscriber sh -c 'psql -P pager=off -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_logical_subscriber_config.sql'

replication-physical-status:
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'psql -P pager=off -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_primary_replication.sql'
	$(COMPOSE) exec -T rental_housing_platform_db_physical_fast sh -c 'psql -P pager=off -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_physical_replica.sql'
	$(COMPOSE) exec -T rental_housing_platform_db_physical_delayed sh -c 'psql -P pager=off -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_physical_replica.sql'

replication-logical-status:
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'psql -P pager=off -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_logical_publisher.sql'
	$(COMPOSE) exec -T rental_housing_platform_db_logical_subscriber sh -c 'psql -P pager=off -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_logical_subscriber.sql'

replication-capture:
	@powershell -NoProfile -Command "New-Item -ItemType Directory -Force artifacts/replication | Out-Null"
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'psql -P pager=off -o /workspace/artifacts/replication/primary_config.txt -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_primary_config.sql'
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'psql -P pager=off -o /workspace/artifacts/replication/primary_replication_status.txt -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_primary_replication.sql'
	$(COMPOSE) exec -T rental_housing_platform_db_physical_fast sh -c 'psql -P pager=off -o /workspace/artifacts/replication/physical_fast_status.txt -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_physical_replica.sql'
	$(COMPOSE) exec -T rental_housing_platform_db_physical_delayed sh -c 'psql -P pager=off -o /workspace/artifacts/replication/physical_delayed_status.txt -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_physical_replica.sql'
	$(COMPOSE) exec -T rental_housing_platform_db_logical_subscriber sh -c 'psql -P pager=off -o /workspace/artifacts/replication/logical_subscriber_config.txt -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_logical_subscriber_config.sql'
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'psql -P pager=off -o /workspace/artifacts/replication/logical_publisher_status.txt -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_logical_publisher.sql'
	$(COMPOSE) exec -T rental_housing_platform_db_logical_subscriber sh -c 'psql -P pager=off -o /workspace/artifacts/replication/logical_subscriber_status.txt -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_logical_subscriber.sql'

replication-capture-logical-demo:
	@powershell -NoProfile -Command "New-Item -ItemType Directory -Force artifacts/replication | Out-Null"
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'psql -P pager=off -o /workspace/artifacts/replication/logical_insert_primary.txt -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/insert_logical_demo_currency.sql'
	@powershell -NoProfile -Command "Start-Sleep -Seconds 3"
	$(COMPOSE) exec -T rental_housing_platform_db_logical_subscriber sh -c 'psql -P pager=off -o /workspace/artifacts/replication/logical_subscriber_after_insert.txt -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_logical_subscriber.sql'

replication-capture-physical-delay:
	@powershell -NoProfile -Command "New-Item -ItemType Directory -Force artifacts/replication | Out-Null"
	$(COMPOSE) exec -T rental_housing_platform_db sh -c 'psql -P pager=off -o /workspace/artifacts/replication/physical_insert_primary.txt -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/insert_physical_demo_currency.sql'
	@powershell -NoProfile -Command "Start-Sleep -Seconds 10"
	$(COMPOSE) exec -T rental_housing_platform_db_physical_fast sh -c 'psql -P pager=off -o /workspace/artifacts/replication/physical_fast_after_insert.txt -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_physical_replica.sql'
	$(COMPOSE) exec -T rental_housing_platform_db_physical_delayed sh -c 'psql -P pager=off -o /workspace/artifacts/replication/physical_delayed_before_delay.txt -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_physical_replica.sql'
	@powershell -NoProfile -Command "Start-Sleep -Seconds 310"
	$(COMPOSE) exec -T rental_housing_platform_db_physical_delayed sh -c 'psql -P pager=off -o /workspace/artifacts/replication/physical_delayed_after_delay.txt -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/sql/replication/check_physical_replica.sql'

# Полный пересозданный цикл: чистая БД -> миграции -> базовые сиды.
seed-reset: down up migrate-up seed-run
