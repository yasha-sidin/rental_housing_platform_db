#!/bin/sh
set -eu

# Tablespace directories are mounted as separate Docker volumes.
# They must exist and be owned by the postgres OS user before PostgreSQL starts.
TABLESPACE_DIRS="
/var/lib/postgresql/tablespaces/rental_reference
/var/lib/postgresql/tablespaces/rental_core
/var/lib/postgresql/tablespaces/rental_booking
/var/lib/postgresql/tablespaces/rental_history
/var/lib/postgresql/tablespaces/rental_index
"

for dir in $TABLESPACE_DIRS; do
  mkdir -p "$dir"

  if [ "$(id -u)" = "0" ]; then
    chown postgres:postgres "$dir"
    chmod 700 "$dir"
  fi

  echo "OK: ensured PostgreSQL tablespace directory: $dir"
done

exec docker-entrypoint.sh "$@"
