#!/bin/sh
set -eu

required_vars="
POSTGRES_USER
POSTGRES_PASSWORD
PGBOUNCER_ADMIN_USER
PGBOUNCER_ADMIN_PASSWORD
"

for var_name in $required_vars; do
  eval "var_value=\${$var_name:-}"
  if [ -z "$var_value" ]; then
    echo "ERROR: required env var is empty: $var_name" >&2
    exit 1
  fi
done

{
  printf '"%s" "%s"\n' "$POSTGRES_USER" "$POSTGRES_PASSWORD"
  printf '"%s" "%s"\n' "$PGBOUNCER_ADMIN_USER" "$PGBOUNCER_ADMIN_PASSWORD"
} > /tmp/pgbouncer-userlist.txt

exec "$@"
