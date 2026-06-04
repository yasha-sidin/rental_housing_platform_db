#!/usr/bin/env bash
set -euo pipefail

/opt/entrypoint.sh &
pmm_pid="$!"

(
  sleep 5
  bash /etc/pmm/register-services.sh
  python3 /etc/pmm/provision-dashboard.py
) &

trap 'kill "$pmm_pid" 2>/dev/null || true; wait "$pmm_pid" 2>/dev/null || true' TERM INT
wait "$pmm_pid"
