# Используем POSIX shell для всех рецептов Makefile,
# чтобы команды одинаково работали в Linux-контейнерной среде.
SHELL := /bin/sh

# Базовая команда docker compose.
COMPOSE := docker compose

# Шаблон запуска одноразового контейнера миграций.
# --rm удаляет контейнер после выполнения команды.
MIGRATE_RUNNER := $(COMPOSE) run --rm migration_runner

# Количество строк для нагрузочного сида по умолчанию.
N ?= 1000

# Список целей, которые не являются именами файлов.
.PHONY: up down restart logs ps db-shell migrate-check migrate-up migrate-down-one migrate-down migrate-version migrate-force migrate-goto seed-run seed-load seed-clean seed-reset

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

# Открыть psql внутри контейнера БД.
# Переменные POSTGRES_USER/POSTGRES_DB берутся из env контейнера.
db-shell:
	$(COMPOSE) exec rental_housing_platform_db sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

# Проверка парности и корректности формата V/U миграций
# без применения изменений в БД.
migrate-check:
	$(MIGRATE_RUNNER) /app/prepare_migrations.sh --check-only

# Применить все pending миграции вверх.
migrate-up:
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
seed-run:
	$(COMPOSE) exec rental_housing_platform_db sh -c 'psql -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/db/seeds/001_reference.sql'
	$(COMPOSE) exec rental_housing_platform_db sh -c 'psql -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/db/seeds/002_base_entities.sql'
	$(COMPOSE) exec rental_housing_platform_db sh -c 'psql -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/db/seeds/003_scenarios.sql'

# Нагрузочный сид. По умолчанию N=1000, можно переопределить:
# make seed-load N=5000
seed-load:
	@powershell -NoProfile -Command "if ([int]'$(N)' -gt 100000) { Write-Error 'N=$(N) is too large for local run. Max allowed is 100000.'; exit 1 }"
	$(COMPOSE) exec rental_housing_platform_db sh -c 'psql -v ON_ERROR_STOP=1 -v rows=$(N) -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/db/seeds/004_load.sql'

# Очистка load-данных.
seed-clean:
	$(COMPOSE) exec rental_housing_platform_db sh -c 'psql -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /workspace/db/seeds/999_cleanup.sql'

# Полный пересозданный цикл: чистая БД -> миграции -> базовые сиды.
seed-reset: down up migrate-up seed-run
