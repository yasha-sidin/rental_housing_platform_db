#!/bin/sh
set -eu

case "${1:-}" in
  *.yml.tpl)
    ;;
  *)
    exec "$@"
    ;;
esac

required_vars="
POSTGRES_USER
POSTGRES_PASSWORD
POSTGRES_DB
PATRONI_NAME
PATRONI_SCOPE
PATRONI_NAMESPACE
ETCD3_HOSTS
PATRONI_REST_CONNECT_ADDRESS
PATRONI_POSTGRES_CONNECT_ADDRESS
PATRONI_REPLICATION_USERNAME
PATRONI_REPLICATION_PASSWORD
PATRONI_REWIND_USERNAME
PATRONI_REWIND_PASSWORD
"

for var_name in $required_vars; do
  eval "var_value=\${$var_name:-}"
  if [ -z "$var_value" ]; then
    echo "ERROR: required env var is empty: $var_name" >&2
    exit 1
  fi
done

template_path="${1:-/etc/patroni/patroni.yml.tpl}"
rendered_path="/tmp/patroni.yml"

envsubst < "$template_path" > "$rendered_path"
chown postgres:postgres "$rendered_path"
mkdir -p "$PGDATA" /var/run/postgresql /var/log/pgbackrest /var/spool/pgbackrest
chown -R postgres:postgres "$PGDATA" /var/run/postgresql /var/log/pgbackrest /var/spool/pgbackrest
chmod 700 "$PGDATA"

exec gosu postgres /opt/patroni/bin/patroni "$rendered_path"
