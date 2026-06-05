#!/usr/bin/env bash
set -euo pipefail

if [ -f /etc/pmm/rental.env ]; then
  set -a
  # shellcheck disable=SC1091
  . /etc/pmm/rental.env
  set +a
fi

PMM_ADMIN_USER="${PMM_ADMIN_USER:-${GF_SECURITY_ADMIN_USER:-admin}}"
PMM_ADMIN_PASSWORD="${PMM_ADMIN_PASSWORD:-${GF_SECURITY_ADMIN_PASSWORD:-admin}}"
POSTGRES_USER="${POSTGRES_USER:-admin}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"

SERVER_URL="https://${PMM_ADMIN_USER}:${PMM_ADMIN_PASSWORD}@127.0.0.1:8443"
COMMON_FLAGS=(--server-url="${SERVER_URL}" --server-insecure-tls)

log() {
  printf '[pmm-register] %s\n' "$*"
}

wait_for_pmm() {
  for _ in $(seq 1 90); do
    if curl -sk https://127.0.0.1:8443/v1/server/readyz >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  log "PMM Server is not ready"
  return 1
}

wait_for_pmm_agent() {
  for _ in $(seq 1 90); do
    if pmm-admin status 2>/dev/null | grep -q "Connected[[:space:]]*: true"; then
      return 0
    fi
    sleep 2
  done

  log "PMM Agent is not connected"
  return 1
}

reset_admin_password() {
  if [ "$PMM_ADMIN_USER" != "admin" ]; then
    log "PMM_ADMIN_USER is '$PMM_ADMIN_USER', but PMM/Grafana password reset targets the built-in admin user"
  fi

  for _ in $(seq 1 60); do
    if grafana-cli \
      --homepath /usr/share/grafana \
      --config /etc/grafana/grafana.ini \
      admin reset-admin-password "$PMM_ADMIN_PASSWORD" >/dev/null 2>&1; then
      log "PMM admin password is synchronized with PMM_ADMIN_PASSWORD"
      return 0
    fi
    sleep 2
  done

  log "Unable to synchronize PMM admin password"
  return 1
}

service_exists() {
  local service_name="$1"
  pmm-admin inventory list services "${COMMON_FLAGS[@]}" --json 2>/dev/null \
    | grep -q "\"service_name\":\"${service_name}\""
}

add_service_once() {
  local service_name="$1"
  shift

  if service_exists "$service_name"; then
    log "service already registered: $service_name"
    return 0
  fi

  log "registering service: $service_name"
  for attempt in $(seq 1 20); do
    if "$@"; then
      return 0
    fi
    log "registration attempt $attempt failed for $service_name"
    sleep 3
  done

  log "unable to register service: $service_name"
  return 1
}

wait_for_pmm
reset_admin_password
wait_for_pmm_agent

add_service_once "postgres-node-1" \
  pmm-admin add postgresql "${COMMON_FLAGS[@]}" \
    --service-name=postgres-node-1 --host=postgres-node-1 --port=5432 \
    --username="$POSTGRES_USER" --password="$POSTGRES_PASSWORD" --database=postgres \
    --cluster=rental-ha --environment=local --query-source=pgstatements --metrics-mode=auto

add_service_once "postgres-node-2" \
  pmm-admin add postgresql "${COMMON_FLAGS[@]}" \
    --service-name=postgres-node-2 --host=postgres-node-2 --port=5432 \
    --username="$POSTGRES_USER" --password="$POSTGRES_PASSWORD" --database=postgres \
    --cluster=rental-ha --environment=local --query-source=pgstatements --metrics-mode=auto

add_service_once "postgres-node-3" \
  pmm-admin add postgresql "${COMMON_FLAGS[@]}" \
    --service-name=postgres-node-3 --host=postgres-node-3 --port=5432 \
    --username="$POSTGRES_USER" --password="$POSTGRES_PASSWORD" --database=postgres \
    --cluster=rental-ha --environment=local --query-source=pgstatements --metrics-mode=auto

add_service_once "postgres-node-4" \
  pmm-admin add postgresql "${COMMON_FLAGS[@]}" \
    --service-name=postgres-node-4 --host=postgres-node-4 --port=5432 \
    --username="$POSTGRES_USER" --password="$POSTGRES_PASSWORD" --database=postgres \
    --cluster=rental-ha --environment=local --query-source=pgstatements --metrics-mode=auto

add_service_once "postgres-node-5" \
  pmm-admin add postgresql "${COMMON_FLAGS[@]}" \
    --service-name=postgres-node-5 --host=postgres-node-5 --port=5432 \
    --username="$POSTGRES_USER" --password="$POSTGRES_PASSWORD" --database=postgres \
    --cluster=rental-ha --environment=local --query-source=pgstatements --metrics-mode=auto

for idx in 1 2 3 4 5; do
  host="postgres-node-${idx}"
  service="patroni-${host}"
  add_service_once "$service" \
    pmm-admin add external-serverless "${COMMON_FLAGS[@]}" \
      --external-name="$service" --url="http://${host}:8008/metrics" \
      --group=patroni --cluster=rental-ha --environment=local --skip-connection-check
done

for client in a b; do
  host="haproxy-client-${client}"
  add_service_once "$host" \
    pmm-admin add external-serverless "${COMMON_FLAGS[@]}" \
      --external-name="$host" --url="http://${host}:7000/metrics" \
      --group=haproxy --cluster=rental-ha --environment=local --skip-connection-check
done

for idx in 1 2 3 4 5; do
  host="etcd-${idx}"
  add_service_once "$host" \
    pmm-admin add external-serverless "${COMMON_FLAGS[@]}" \
      --external-name="$host" --url="http://${host}:2379/metrics" \
      --group=etcd --cluster=rental-ha --environment=local --skip-connection-check
done

for suffix in a b; do
  host="backup-worker-${suffix}"
  add_service_once "$host" \
    pmm-admin add external-serverless "${COMMON_FLAGS[@]}" \
      --external-name="$host" --url="http://${host}:9190/metrics" \
      --group=backup-worker --cluster=rental-ha --environment=local --skip-connection-check
done

add_service_once "rental-custom-observability" \
  pmm-admin add external-serverless "${COMMON_FLAGS[@]}" \
    --external-name=rental-custom-observability \
    --url=http://pmm-custom-exporter:9187/metrics \
    --group=rental-observability --cluster=rental-ha --environment=local --skip-connection-check

log "registration completed"
