#!/usr/bin/env python3
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

import psycopg


def env_int(name, default):
    value = os.environ.get(name)
    if value is None or value == "":
        return default
    return int(value)


NODE_NAME = os.environ.get("PATRONI_NAME", "postgres-node")
MIN_SYNC_STANDBYS = env_int("WRITE_GUARD_MIN_SYNC_STANDBYS", 2)
PORT = env_int("WRITE_GUARD_PORT", 8010)


def readiness_state():
    user = os.environ.get("POSTGRES_USER")
    password = os.environ.get("POSTGRES_PASSWORD")
    if not user or not password:
        return False, "POSTGRES_USER or POSTGRES_PASSWORD is empty"

    try:
        with psycopg.connect(
            host="127.0.0.1",
            port=5432,
            dbname="postgres",
            user=user,
            password=password,
            connect_timeout=2,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        NOT pg_is_in_recovery() AS is_primary,
                        current_setting('synchronous_commit') AS synchronous_commit,
                        current_setting('synchronous_standby_names') AS synchronous_standby_names,
                        (
                            SELECT count(*)::int
                            FROM pg_stat_replication
                            WHERE state = 'streaming'
                              AND sync_state = 'sync'
                        ) AS sync_standbys
                    """
                )
                is_primary, synchronous_commit, synchronous_standby_names, sync_standbys = cursor.fetchone()
    except Exception as error:
        return False, f"postgres unavailable: {error}"

    details = (
        f"node={NODE_NAME} "
        f"is_primary={str(is_primary).lower()} "
        f"synchronous_commit={synchronous_commit} "
        f"sync_standbys={sync_standbys} "
        f"required_sync_standbys={MIN_SYNC_STANDBYS} "
        f"synchronous_standby_names={synchronous_standby_names!r}"
    )

    if not is_primary:
        return False, details
    if synchronous_commit in ("off", "local"):
        return False, details
    if sync_standbys < MIN_SYNC_STANDBYS:
        return False, details
    return True, details


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/", "/ready-write"):
            self.send_response(404)
            self.end_headers()
            return

        ready, details = readiness_state()
        status = 200 if ready else 503
        prefix = "ready" if ready else "not ready"
        body = f"{prefix}: {details}\n".encode("utf-8")

        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        return


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
