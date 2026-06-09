#!/usr/bin/env bash
set -euo pipefail

cleanup_stale_postmaster_pid() {
  local pid_file="/srv/postgres14/postmaster.pid"
  local pid=""

  if [ ! -f "$pid_file" ]; then
    return 0
  fi

  pid="$(head -n 1 "$pid_file" 2>/dev/null || true)"
  if [ -n "$pid" ] && [ -d "/proc/$pid" ]; then
    if tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q "postgres"; then
      return 0
    fi
  fi

  rm -f "$pid_file"
}

cleanup_stale_postmaster_pid

/opt/entrypoint.sh &
pmm_pid="$!"

(
  sleep 5
  bash /etc/pmm/register-services.sh
  python3 /etc/pmm/provision-dashboard.py
) &

trap 'kill "$pmm_pid" 2>/dev/null || true; wait "$pmm_pid" 2>/dev/null || true' TERM INT
wait "$pmm_pid"
