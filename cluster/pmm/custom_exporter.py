#!/usr/bin/env python3
import json
import os
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


POSTGRES_NODES = [f"postgres-node-{idx}" for idx in range(1, 6)]
ETCD_NODES = [f"etcd-{idx}" for idx in range(1, 6)]
HTTP_TIMEOUT = float(os.environ.get("PMM_CUSTOM_EXPORTER_HTTP_TIMEOUT", "0.75"))
PSQL_CONNECT_TIMEOUT = os.environ.get("PMM_CUSTOM_EXPORTER_PSQL_CONNECT_TIMEOUT", "1")
PSQL_COMMAND_TIMEOUT = float(os.environ.get("PMM_CUSTOM_EXPORTER_PSQL_COMMAND_TIMEOUT", "1"))
PGBACKREST_TIMEOUT = float(os.environ.get("PMM_CUSTOM_EXPORTER_PGBACKREST_TIMEOUT", "1"))


def metric(name, value, labels=None):
    label_text = ""
    if labels:
        pairs = [f'{key}="{str(val).replace(chr(34), chr(92) + chr(34))}"' for key, val in labels.items()]
        label_text = "{" + ",".join(pairs) + "}"
    return f"{name}{label_text} {value}"


def http_get(url, timeout=HTTP_TIMEOUT):
    completed = subprocess.run(
        [
            "curl",
            "-sS",
            "--connect-timeout",
            str(timeout),
            "--max-time",
            str(timeout),
            "-o",
            "/dev/null",
            "-w",
            "%{http_code}",
            url,
        ],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout + 0.5,
    )
    status_text = completed.stdout.strip()
    status = int(status_text[-3:]) if status_text else 0
    if completed.returncode != 0 and status == 0:
        raise RuntimeError(completed.stderr.strip() or "HTTP request failed")
    return status, b""


def http_status(url, timeout=HTTP_TIMEOUT):
    status, _ = http_get(url, timeout=timeout)
    return status


def http_status_metrics(lines, name, url, labels):
    try:
        status, _ = http_get(url)
        lines.append(metric(name, 1 if 200 <= status < 300 else 0, labels))
        lines.append(metric(f"{name}_status_code", status, labels))
    except Exception:
        lines.append(metric(name, 0, labels))
        lines.append(metric(f"{name}_status_code", 0, labels))


def collect_http_status(name, url, labels):
    lines = []
    http_status_metrics(lines, name, url, labels)
    return lines


def collect_patroni_node_metrics(node):
    lines = []
    health_status = 0
    primary_status = 0
    replica_status = 0

    try:
        health_status = http_status(f"http://{node}:8008/health")
    except Exception:
        pass
    if 200 <= health_status < 300:
        try:
            primary_status = http_status(f"http://{node}:8008/primary")
        except Exception:
            pass
        try:
            replica_status = http_status(f"http://{node}:8008/replica")
        except Exception:
            pass

    lines.append(metric("rental_patroni_up", 1 if 200 <= health_status < 300 else 0, {"node": node}))
    lines.append(metric("rental_patroni_up_status_code", health_status, {"node": node}))
    lines.append(metric("rental_patroni_primary", 1 if 200 <= primary_status < 300 else 0, {"node": node}))
    lines.append(metric("rental_patroni_primary_status_code", primary_status, {"node": node}))
    lines.append(metric("rental_patroni_replica", 1 if 200 <= replica_status < 300 else 0, {"node": node}))
    lines.append(metric("rental_patroni_replica_status_code", replica_status, {"node": node}))

    if not 200 <= health_status < 300:
        component_state(lines, "PostgreSQL/Patroni", node, "down", "down", "Patroni REST API is unreachable")
    elif 200 <= primary_status < 300:
        component_state(lines, "PostgreSQL/Patroni", node, "primary", "up", "Patroni REST API is healthy")
    elif 200 <= replica_status < 300:
        component_state(lines, "PostgreSQL/Patroni", node, "replica", "up", "Patroni REST API is healthy")
    else:
        component_state(lines, "PostgreSQL/Patroni", node, "unknown", "up", "Patroni REST API is healthy")

    return lines


def component_state(lines, component_type, component, state, health, detail):
    lines.append(
        metric(
            "rental_component_state",
            1 if health == "up" else 0,
            {
                "component_type": component_type,
                "component": component,
                "state": state,
                "health": health,
                "detail": detail,
            },
        )
    )


def collector_status_metrics(name, up, duration):
    labels = {"collector": name}
    return [
        metric("rental_custom_exporter_collector_up", up, labels),
        metric("rental_custom_exporter_collector_duration_seconds", f"{duration:.6f}", labels),
    ]


def collector_error_metrics(name, error, duration):
    labels = {"collector": name, "error": type(error).__name__}
    return [
        *collector_status_metrics(name, 0, duration),
        metric("rental_custom_exporter_collector_error", 1, labels),
    ]


def normalize_collector(collector):
    if isinstance(collector, tuple):
        return collector
    return getattr(collector, "__name__", "collector"), collector


def run_collector(name, collector):
    started = time.monotonic()
    try:
        collected = collector()
        duration = time.monotonic() - started
        return collected + collector_status_metrics(name, 1, duration)
    except Exception as error:
        duration = time.monotonic() - started
        return collector_error_metrics(name, error, duration)


def append_parallel(lines, collectors, max_workers=10):
    if not collectors:
        return

    normalized = [normalize_collector(collector) for collector in collectors]
    with ThreadPoolExecutor(max_workers=min(max_workers, len(normalized))) as executor:
        futures = {executor.submit(run_collector, name, collector): name for name, collector in normalized}
        for future in as_completed(futures):
            name = futures[future]
            try:
                lines.extend(future.result())
            except Exception as error:
                lines.extend(collector_error_metrics(name, error, 0))


def collect_from_lines(func, *args):
    lines = []
    func(lines, *args)
    return lines


def command_output(args, env=None, timeout=PSQL_COMMAND_TIMEOUT):
    completed = subprocess.run(
        args,
        check=True,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout,
    )
    return completed.stdout


def postgres_recovery_status(node, env, user, database):
    try:
        output = command_output(
            [
                "psql",
                "-h",
                node,
                "-U",
                user,
                "-d",
                database,
                "-A",
                "-t",
                "-c",
                "SELECT pg_is_in_recovery();",
            ],
            env=env,
            timeout=PSQL_COMMAND_TIMEOUT,
        ).strip()
        return node, output
    except Exception:
        return node, None


def postgres_cluster_metrics(lines):
    env = os.environ.copy()
    env["PGPASSWORD"] = os.environ.get("POSTGRES_PASSWORD", "")
    env["PGCONNECT_TIMEOUT"] = PSQL_CONNECT_TIMEOUT
    user = os.environ.get("POSTGRES_USER", "")
    database = os.environ.get("POSTGRES_DB", "postgres")
    primary_node = None

    executor = ThreadPoolExecutor(max_workers=len(POSTGRES_NODES))
    futures = [
        executor.submit(postgres_recovery_status, node, env, user, database)
        for node in POSTGRES_NODES
    ]
    try:
        for future in as_completed(futures):
            node, output = future.result()
            if output == "f":
                primary_node = node
                break
    finally:
        if primary_node:
            for future in futures:
                if not future.done():
                    future.cancel()
            executor.shutdown(wait=False, cancel_futures=True)
        else:
            executor.shutdown(wait=True)

    if not primary_node:
        lines.append(metric("rental_postgres_primary_sql_up", 0, {"node": ""}))
        component_state(lines, "PostgreSQL SQL", "primary", "down", "down", "primary SQL endpoint was not found")
        return

    labels = {"node": primary_node}
    sql = """
SELECT
  (SELECT count(*) FROM pg_stat_replication WHERE state = 'streaming') AS streaming_replicas,
  (SELECT count(*) FROM pg_stat_replication WHERE sync_state = 'sync') AS sync_standbys,
  (SELECT COALESCE(max(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)), 0) FROM pg_stat_replication) AS max_lag_bytes,
  (SELECT archived_count FROM pg_stat_archiver) AS archived_count,
  (SELECT failed_count FROM pg_stat_archiver) AS failed_count,
  (SELECT COALESCE(EXTRACT(EPOCH FROM now() - last_archived_time), -1) FROM pg_stat_archiver) AS last_archive_age_seconds;
""".strip()

    try:
        output = command_output(
            [
                "psql",
                "-h",
                primary_node,
                "-U",
                user,
                "-d",
                database,
                "-A",
                "-t",
                "-F",
                "|",
                "-c",
                sql,
            ],
            env=env,
            timeout=PSQL_COMMAND_TIMEOUT,
        ).strip()
        values = output.split("|")
        lines.append(metric("rental_postgres_primary_sql_up", 1, labels))
        lines.append(metric("rental_postgres_streaming_replica_count", values[0], labels))
        lines.append(metric("rental_postgres_sync_standby_count", values[1], labels))
        lines.append(metric("rental_postgres_replication_lag_bytes", values[2], labels))
        lines.append(metric("rental_pg_wal_archiver_archived_count", values[3], labels))
        lines.append(metric("rental_pg_wal_archiver_failed_count", values[4], labels))
        lines.append(metric("rental_pg_wal_archiver_last_archive_age_seconds", values[5], labels))
        component_state(lines, "PostgreSQL SQL", primary_node, "primary SQL readable", "up", "replication and WAL queries succeeded")
    except Exception:
        lines.append(metric("rental_postgres_primary_sql_up", 0, labels))
        component_state(lines, "PostgreSQL SQL", primary_node, "down", "down", "replication and WAL queries failed")


def patroni_component_for_node(node):
    lines = []
    try:
        health_status = http_status(f"http://{node}:8008/health")
        if not 200 <= health_status < 300:
            component_state(lines, "PostgreSQL/Patroni", node, "down", "down", "Patroni health is not ready")
            return lines

        try:
            primary_status = http_status(f"http://{node}:8008/primary")
        except Exception:
            primary_status = 0
        try:
            replica_status = http_status(f"http://{node}:8008/replica")
        except Exception:
            replica_status = 0

        if 200 <= primary_status < 300:
            state = "primary"
        elif 200 <= replica_status < 300:
            state = "replica"
        else:
            state = "unknown"

        component_state(lines, "PostgreSQL/Patroni", node, state, "up", "Patroni REST API is healthy")
    except Exception:
        component_state(lines, "PostgreSQL/Patroni", node, "down", "down", "Patroni REST API is unreachable")
    return lines


def patroni_component_metrics(lines):
    append_parallel(
        lines,
        [(f"patroni_component_{node}", lambda node=node: patroni_component_for_node(node)) for node in POSTGRES_NODES],
    )


def http_component_metrics(lines):
    checks = [
        ("etcd", node, f"http://{node}:2379/health", "healthy", "etcd health endpoint") for node in ETCD_NODES
    ]
    checks.extend(
        [
            ("MinIO", "minio", "http://minio:9000/minio/health/live", "healthy", "MinIO live endpoint"),
            ("HAProxy", "haproxy-client-a", "http://haproxy-client-a:7000/", "healthy", "HAProxy stats endpoint"),
            ("HAProxy", "haproxy-client-b", "http://haproxy-client-b:7000/", "healthy", "HAProxy stats endpoint"),
            ("Backup worker", "backup-worker-a", "http://backup-worker-a:9190/health", "exporter up", "backup worker exporter"),
            ("Backup worker", "backup-worker-b", "http://backup-worker-b:9190/health", "exporter up", "backup worker exporter"),
        ]
    )

    def collect_check(component_type, component, url, state, detail):
        local_lines = []
        try:
            status = http_status(url)
            health = "up" if 200 <= status < 300 else "down"
            component_state(local_lines, component_type, component, state if health == "up" else "down", health, detail)
        except Exception:
            component_state(local_lines, component_type, component, "down", "down", detail)
        return local_lines

    append_parallel(
        lines,
        [
            (
                f"component_{component_type}_{component}",
                lambda component_type=component_type, component=component, url=url, state=state, detail=detail: collect_check(
                    component_type, component, url, state, detail
                ),
            )
            for component_type, component, url, state, detail in checks
        ],
    )


def pgbouncer_metrics(lines, client, host, user_env, password_env):
    env = os.environ.copy()
    env["PGPASSWORD"] = os.environ.get(password_env, "")
    env["PGCONNECT_TIMEOUT"] = PSQL_CONNECT_TIMEOUT
    user = os.environ.get(user_env, "")
    labels = {"client": client, "host": host}

    try:
        output = command_output(
            [
                "psql",
                "-h",
                host,
                "-p",
                "6432",
                "-U",
                user,
                "-d",
                "pgbouncer",
                "-A",
                "-F",
                "|",
                "-P",
                "footer=off",
                "-c",
                "SHOW POOLS;",
            ],
            env=env,
            timeout=PSQL_COMMAND_TIMEOUT,
        )
        rows = [row for row in output.strip().splitlines() if row]
        headers = rows[0].split("|") if rows else []
        lines.append(metric("rental_pgbouncer_up", 1, labels))
        component_state(lines, "PgBouncer", host, "pooling", "up", "administrative SHOW POOLS succeeded")

        for row in rows[1:]:
            values = row.split("|")
            data = dict(zip(headers, values))
            row_labels = {
                "client": client,
                "database": data.get("database", ""),
                "user": data.get("user", ""),
            }
            for column in ("cl_active", "cl_waiting", "sv_active", "sv_idle", "sv_used", "sv_login"):
                if column in data and data[column] != "":
                    lines.append(metric(f"rental_pgbouncer_{column}", data[column], row_labels))
    except Exception:
        lines.append(metric("rental_pgbouncer_up", 0, labels))
        component_state(lines, "PgBouncer", host, "down", "down", "administrative SHOW POOLS failed")


def pgbackrest_metrics(lines):
    labels = {"stanza": os.environ.get("PGBACKREST_STANZA", "rental")}
    try:
        output = command_output(
            ["pgbackrest", f"--stanza={labels['stanza']}", "info", "--output=json"],
            timeout=PGBACKREST_TIMEOUT,
        )
        data = json.loads(output)
        stanza = data[0] if data else {}
        backups = []
        for repo in stanza.get("repo", []):
            backups.extend(repo.get("backup", []))

        lines.append(metric("rental_pgbackrest_info_up", 1, labels))
        lines.append(metric("rental_pgbackrest_backup_count", len(backups), labels))
        component_state(lines, "Backup repository", "pgBackRest", "repository readable", "up", "pgbackrest info succeeded")

        full_backups = [backup for backup in backups if backup.get("type") == "full"]
        if full_backups:
            latest = max(full_backups, key=lambda item: item.get("timestamp", {}).get("stop", 0))
            lines.append(
                metric(
                    "rental_pgbackrest_latest_full_backup_stop_timestamp",
                    latest.get("timestamp", {}).get("stop", 0),
                    labels,
                )
            )
    except Exception:
        lines.append(metric("rental_pgbackrest_info_up", 0, labels))
        component_state(lines, "Backup repository", "pgBackRest", "down", "down", "pgbackrest info failed")


def collect_metrics():
    lines = [
        "# HELP rental_patroni_up Patroni REST health availability.",
        "# TYPE rental_patroni_up gauge",
        "# HELP rental_custom_exporter_collector_up Collector-level availability inside the custom exporter.",
        "# TYPE rental_custom_exporter_collector_up gauge",
        "# HELP rental_custom_exporter_collector_duration_seconds Collector duration inside the custom exporter.",
        "# TYPE rental_custom_exporter_collector_duration_seconds gauge",
        "# HELP rental_custom_exporter_collector_error Collector-level exception marker inside the custom exporter.",
        "# TYPE rental_custom_exporter_collector_error gauge",
    ]

    append_parallel(
        lines,
        [
            (
                "patroni_nodes",
                lambda: collect_from_lines(
                    append_parallel,
                    [(f"patroni_{node}", lambda node=node: collect_patroni_node_metrics(node)) for node in POSTGRES_NODES],
                    20,
                ),
            ),
            (
                "etcd_nodes",
                lambda: collect_from_lines(
                    append_parallel,
                    [
                        (
                            f"etcd_{node}",
                            lambda node=node: collect_http_status(
                                "rental_etcd_up",
                                f"http://{node}:2379/health",
                                {"node": node},
                            ),
                        )
                        for node in ETCD_NODES
                    ],
                    20,
                ),
            ),
            ("component_states", lambda: collect_from_lines(http_component_metrics)),
            ("postgres_sql", lambda: collect_from_lines(postgres_cluster_metrics)),
            (
                "minio_status",
                lambda: collect_http_status("rental_minio_up", "http://minio:9000/minio/health/live", {"service": "minio"}),
            ),
            (
                "haproxy_client_a_status",
                lambda: collect_http_status("rental_haproxy_stats_up", "http://haproxy-client-a:7000/", {"client": "a"}),
            ),
            (
                "haproxy_client_b_status",
                lambda: collect_http_status("rental_haproxy_stats_up", "http://haproxy-client-b:7000/", {"client": "b"}),
            ),
            (
                "pgbouncer_client_a",
                lambda: collect_from_lines(
                    pgbouncer_metrics,
                    "a",
                    "pgbouncer-client-a",
                    "PGBOUNCER_CLIENT_A_ADMIN_USER",
                    "PGBOUNCER_CLIENT_A_ADMIN_PASSWORD",
                ),
            ),
            (
                "pgbouncer_client_b",
                lambda: collect_from_lines(
                    pgbouncer_metrics,
                    "b",
                    "pgbouncer-client-b",
                    "PGBOUNCER_CLIENT_B_ADMIN_USER",
                    "PGBOUNCER_CLIENT_B_ADMIN_PASSWORD",
                ),
            ),
            ("pgbackrest", lambda: collect_from_lines(pgbackrest_metrics)),
        ],
        max_workers=20,
    )

    component_state(lines, "Observability", "pmm-custom-exporter", "exporting", "up", "custom exporter process is running")
    lines.append(metric("rental_custom_exporter_scrape_timestamp", int(time.time())))
    return "\n".join(lines) + "\n"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/", "/metrics"):
            self.send_response(404)
            self.end_headers()
            return

        body = collect_metrics().encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except BrokenPipeError:
            pass

    def log_message(self, fmt, *args):
        return


if __name__ == "__main__":
    port = int(os.environ.get("PMM_CUSTOM_EXPORTER_PORT", "9187"))
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
