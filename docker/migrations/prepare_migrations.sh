#!/bin/sh

# Включаем строгий режим:
# -e: завершить скрипт при любой ошибке команды
# -u: считать ошибкой обращение к несуществующей переменной
set -eu

# Каталог с up-миграциями исходного формата проекта (V*.sql).
SOURCE_UP_DIR="${SOURCE_UP_DIR:-/workspace/db/migrations}"

# Каталог с down-миграциями исходного формата проекта (U*.sql).
SOURCE_DOWN_DIR="${SOURCE_DOWN_DIR:-/workspace/db/rollback}"

# Временный каталог, куда будет собран формат для golang-migrate (*.up.sql/*.down.sql).
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/migrations}"

# Флаг режима валидации:
# 0 = подготовка файлов,
# 1 = только проверка парности и формата, без копирования.
CHECK_ONLY=0

# Разбор аргументов скрипта.
while [ "$#" -gt 0 ]; do
  case "$1" in
    # Пользователь может явно указать каталог назначения.
    --output)
      if [ "$#" -lt 2 ]; then
        echo "ERROR: --output requires a path argument" >&2
        exit 1
      fi
      OUTPUT_DIR="$2"
      shift 2
      ;;

    # Режим только проверки (без генерации файлов).
    --check-only)
      CHECK_ONLY=1
      shift
      ;;

    # Любой неизвестный аргумент считаем ошибкой ввода.
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Проверяем существование каталога up-миграций.
if [ ! -d "$SOURCE_UP_DIR" ]; then
  echo "ERROR: up migrations directory not found: $SOURCE_UP_DIR" >&2
  exit 1
fi

# Проверяем существование каталога down-миграций.
if [ ! -d "$SOURCE_DOWN_DIR" ]; then
  echo "ERROR: down migrations directory not found: $SOURCE_DOWN_DIR" >&2
  exit 1
fi

# Собираем список up-миграций в стабильном порядке (sort),
# чтобы всегда получать предсказуемую последовательность версий.
UP_FILES=$(find "$SOURCE_UP_DIR" -maxdepth 1 -type f -name 'V*.sql' | sort)
if [ -z "$UP_FILES" ]; then
  echo "ERROR: no V*.sql files found in $SOURCE_UP_DIR" >&2
  exit 1
fi

# В режиме подготовки очищаем и создаем выходной каталог.
if [ "$CHECK_ONLY" -eq 0 ]; then
  rm -rf "$OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR"
fi

# Проходим по каждой up-миграции и ищем ей строго одну пару down.
for up_file in $UP_FILES; do
  # Имя файла без пути, например V005__create_table.sql
  up_base=$(basename "$up_file")

  # Извлекаем номер версии из формата VNNN__name.sql.
  version_raw=$(printf '%s' "$up_base" | sed -E 's/^V([0-9]+)__.*$/\1/')
  if [ -z "$version_raw" ] || [ "$version_raw" = "$up_base" ]; then
    echo "ERROR: invalid up migration filename format: $up_base" >&2
    exit 1
  fi

  # Извлекаем имя миграции (часть после __ и до .sql).
  name_raw=$(printf '%s' "$up_base" | sed -E 's/^V[0-9]+__(.*)\.sql$/\1/')
  if [ -z "$name_raw" ] || [ "$name_raw" = "$up_base" ]; then
    echo "ERROR: invalid up migration name in file: $up_base" >&2
    exit 1
  fi

  # Ищем все down-файлы с тем же номером версии.
  down_matches=$(find "$SOURCE_DOWN_DIR" -maxdepth 1 -type f -name "U${version_raw}__*.sql" | sort)
  down_count=$(printf '%s\n' "$down_matches" | sed '/^$/d' | wc -l | tr -d ' ')

  # Для корректной обратимости должна быть хотя бы одна down-миграция.
  if [ "$down_count" -eq 0 ]; then
    echo "ERROR: no down migration found for version ${version_raw} (${up_base})" >&2
    exit 1
  fi

  # Для однозначности должна быть ровно одна down-миграция.
  if [ "$down_count" -gt 1 ]; then
    echo "ERROR: more than one down migration found for version ${version_raw}" >&2
    printf '%s\n' "$down_matches" >&2
    exit 1
  fi

  # Берем найденную пару down-файла.
  down_file=$(printf '%s\n' "$down_matches" | head -n 1)

  # Убираем ведущие нули (например 005 -> 5),
  # затем снова форматируем в 3 цифры для имени файла migrate (005).
  version_num=$(printf '%s' "$version_raw" | sed -E 's/^0+//')
  if [ -z "$version_num" ]; then
    version_num=0
  fi

  version_fmt=$(printf '%03d' "$version_num")

  # В режиме подготовки копируем пару в формат golang-migrate:
  # 005_name.up.sql и 005_name.down.sql.
  if [ "$CHECK_ONLY" -eq 0 ]; then
    cp "$up_file" "$OUTPUT_DIR/${version_fmt}_${name_raw}.up.sql"
    cp "$down_file" "$OUTPUT_DIR/${version_fmt}_${name_raw}.down.sql"
  fi
done

# Дополнительная обратная проверка:
# каждый down-файл обязан иметь соответствующий up-файл той же версии.
DOWN_FILES=$(find "$SOURCE_DOWN_DIR" -maxdepth 1 -type f -name 'U*.sql' | sort)
if [ -n "$DOWN_FILES" ]; then
  for down_file in $DOWN_FILES; do
    down_base=$(basename "$down_file")
    down_version=$(printf '%s' "$down_base" | sed -E 's/^U([0-9]+)__.*$/\1/')

    # Проверяем формат имени down-файла.
    if [ -z "$down_version" ] || [ "$down_version" = "$down_base" ]; then
      echo "ERROR: invalid down migration filename format: $down_base" >&2
      exit 1
    fi

    # Проверяем, что есть соответствующий up-файл с тем же номером версии.
    paired_up_count=$(find "$SOURCE_UP_DIR" -maxdepth 1 -type f -name "V${down_version}__*.sql" | wc -l | tr -d ' ')
    if [ "$paired_up_count" -eq 0 ]; then
      echo "ERROR: down migration has no matching up migration: $down_base" >&2
      exit 1
    fi
  done
fi

# Итоговое сообщение зависит от режима запуска.
if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "OK: migration pairs are valid"
else
  echo "OK: migrations prepared in $OUTPUT_DIR"
fi
