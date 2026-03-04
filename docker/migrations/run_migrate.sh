#!/bin/sh

# Включаем строгий режим выполнения.
# -e: прерываемся на первой ошибке
# -u: ошибка при обращении к неинициализированной переменной
set -eu

# Требуем как минимум один аргумент — команду для migrate.
# Примеры: up, down 1, version, goto 8, force 8.
if [ "$#" -lt 1 ]; then
  echo "Usage: /app/run_migrate.sh <migrate args...>" >&2
  echo "Examples:" >&2
  echo "  /app/run_migrate.sh up" >&2
  echo "  /app/run_migrate.sh down 1" >&2
  echo "  /app/run_migrate.sh version" >&2
  exit 1
fi

# Перед любым запуском migrate собираем временный каталог в нужном формате.
# Исходные V/U файлы при этом не меняются.
/app/prepare_migrations.sh --output /tmp/migrations

# Параметры подключения к БД с дефолтами для docker-compose сети.
DB_HOST="${DB_HOST:-rental_housing_platform_db}"
DB_PORT="${DB_PORT:-5432}"
DB_SSLMODE="${DB_SSLMODE:-disable}"

# Проверяем, что критичные env-переменные из .env действительно переданы.
if [ -z "${POSTGRES_USER:-}" ] || [ -z "${POSTGRES_PASSWORD:-}" ] || [ -z "${POSTGRES_DB:-}" ]; then
  echo "ERROR: POSTGRES_USER, POSTGRES_PASSWORD and POSTGRES_DB must be set" >&2
  exit 1
fi

# Формируем стандартный DSN для PostgreSQL, который понимает golang-migrate.
DATABASE_URL="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${DB_HOST}:${DB_PORT}/${POSTGRES_DB}?sslmode=${DB_SSLMODE}"

# Передаем управление утилите migrate.
# exec заменяет текущий процесс скрипта процессом migrate,
# чтобы корректно пробрасывались коды завершения и сигналы.
exec migrate -path /tmp/migrations -database "$DATABASE_URL" "$@"
