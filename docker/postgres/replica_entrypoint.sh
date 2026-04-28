#!/bin/sh
set -eu

# Физические реплики используют те же пути tablespaces, что и primary,
# но каждая реплика получает собственные Docker volumes для этих путей.
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

  echo "OK: ensured PostgreSQL replica tablespace directory: $dir"
done

: "${PGDATA:?PGDATA is required}"
: "${PRIMARY_HOST:?PRIMARY_HOST is required}"
: "${PRIMARY_PORT:=5432}"
: "${PHYSICAL_REPLICATION_USER:?PHYSICAL_REPLICATION_USER is required}"
: "${PHYSICAL_REPLICATION_PASSWORD:?PHYSICAL_REPLICATION_PASSWORD is required}"
: "${PHYSICAL_REPLICATION_SLOT:?PHYSICAL_REPLICATION_SLOT is required}"
: "${REPLICATION_APPLICATION_NAME:?REPLICATION_APPLICATION_NAME is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "Replica data directory is empty. Running pg_basebackup from $PRIMARY_HOST:$PRIMARY_PORT"

  mkdir -p "$PGDATA"
  rm -rf "$PGDATA"/*

  for dir in $TABLESPACE_DIRS; do
    find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  done

  chown -R postgres:postgres "$PGDATA"
  chmod 700 "$PGDATA"

  export PGPASSWORD="$PHYSICAL_REPLICATION_PASSWORD"

  until pg_isready -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U "$PHYSICAL_REPLICATION_USER" -d "$POSTGRES_DB"; do
    echo "Waiting for primary PostgreSQL at $PRIMARY_HOST:$PRIMARY_PORT"
    sleep 1
  done

  gosu postgres pg_basebackup \
    -h "$PRIMARY_HOST" \
    -p "$PRIMARY_PORT" \
    -D "$PGDATA" \
    -U "$PHYSICAL_REPLICATION_USER" \
    -S "$PHYSICAL_REPLICATION_SLOT" \
    -Fp \
    -Xs \
    -P

  touch "$PGDATA/standby.signal"

  cat > "$PGDATA/postgresql.auto.conf" <<EOF
primary_conninfo = 'host=$PRIMARY_HOST port=$PRIMARY_PORT user=$PHYSICAL_REPLICATION_USER password=$PHYSICAL_REPLICATION_PASSWORD application_name=$REPLICATION_APPLICATION_NAME'
EOF

  chown -R postgres:postgres "$PGDATA"
  chmod 700 "$PGDATA"

  echo "Replica base backup completed for application_name=$REPLICATION_APPLICATION_NAME"
fi

exec docker-entrypoint.sh "$@"
