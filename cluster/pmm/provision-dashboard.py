#!/usr/bin/env python3
import base64
import json
import os
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen


API_BASE = "http://127.0.0.1:8080/graph/api"
DASHBOARD_UID = "rental-ha-overview"
DATASOURCE = {"type": "prometheus", "uid": "PA58DA793C7250F1B"}


def load_env_file(path):
    if not os.path.exists(path):
        return

    with open(path, "r", encoding="utf-8") as stream:
        for raw_line in stream:
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            os.environ.setdefault(key, value.strip().strip("\"'"))


def auth_header():
    load_env_file("/etc/pmm/rental.env")
    user = os.environ.get("PMM_ADMIN_USER") or os.environ.get("GF_SECURITY_ADMIN_USER") or "admin"
    password = os.environ.get("PMM_ADMIN_PASSWORD") or os.environ.get("GF_SECURITY_ADMIN_PASSWORD") or "admin"
    token = base64.b64encode(f"{user}:{password}".encode("utf-8")).decode("ascii")
    return {"Authorization": f"Basic {token}"}


def api_request(method, path, payload=None):
    data = None
    headers = auth_header()
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = Request(f"{API_BASE}{path}", data=data, headers=headers, method=method)
    with urlopen(request, timeout=20) as response:
        body = response.read()
        if not body:
            return {}
        return json.loads(body.decode("utf-8"))


def wait_for_grafana():
    for _ in range(90):
        try:
            api_request("GET", "/health")
            return
        except Exception:
            time.sleep(2)
    raise RuntimeError("Grafana API is not ready")


def target(expr, legend="", ref_id="A", instant=False, result_format=None):
    data = {
        "datasource": DATASOURCE,
        "expr": expr,
        "instant": instant,
        "legendFormat": legend,
        "refId": ref_id,
    }
    if result_format:
        data["format"] = result_format
    return data


def zero_when_missing(expr):
    return f"({expr}) or vector(0)"


def thresholds_for_count(expected):
    steps = [{"color": "red", "value": None}]
    if expected > 1:
        steps.append({"color": "orange", "value": 1})
    steps.append({"color": "green", "value": expected})
    return {"mode": "absolute", "steps": steps}


def thresholds_green_until(limit):
    return {
        "mode": "absolute",
        "steps": [
            {"color": "green", "value": None},
            {"color": "red", "value": limit},
        ],
    }


def thresholds_for_lag_bytes():
    return {
        "mode": "absolute",
        "steps": [
            {"color": "green", "value": None},
            {"color": "orange", "value": 1048576},
            {"color": "red", "value": 67108864},
        ],
    }


def stat_panel(panel_id, title, expr, x, y, w, h, expected=None, unit="short"):
    thresholds = thresholds_for_count(expected) if expected is not None else thresholds_for_count(1)
    return {
        "id": panel_id,
        "type": "stat",
        "title": title,
        "datasource": DATASOURCE,
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "targets": [target(expr, title, "A", instant=True)],
        "fieldConfig": {
            "defaults": {
                "unit": unit,
                "thresholds": thresholds,
                "mappings": [],
            },
            "overrides": [],
        },
        "options": {
            "colorMode": "background",
            "graphMode": "none",
            "justifyMode": "center",
            "orientation": "auto",
            "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
            "textMode": "auto",
        },
    }


def timeseries_panel(panel_id, title, targets, x, y, w, h, unit="short"):
    return {
        "id": panel_id,
        "type": "timeseries",
        "title": title,
        "datasource": DATASOURCE,
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "targets": targets,
        "fieldConfig": {
            "defaults": {
                "unit": unit,
                "custom": {
                    "drawStyle": "line",
                    "lineInterpolation": "linear",
                    "lineWidth": 2,
                    "fillOpacity": 8,
                    "showPoints": "never",
                    "spanNulls": False,
                },
            },
            "overrides": [],
        },
        "options": {
            "legend": {"displayMode": "list", "placement": "bottom", "showLegend": True},
            "tooltip": {"mode": "multi", "sort": "none"},
        },
    }


def table_panel(panel_id, title, expr, x, y, w, h):
    return {
        "id": panel_id,
        "type": "table",
        "title": title,
        "datasource": DATASOURCE,
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "targets": [target(expr, "component state", "A", instant=True, result_format="table")],
        "fieldConfig": {
            "defaults": {
                "custom": {
                    "align": "auto",
                    "cellOptions": {"type": "auto"},
                    "inspect": False,
                },
                "thresholds": {
                    "mode": "absolute",
                    "steps": [
                        {"color": "red", "value": None},
                        {"color": "green", "value": 1},
                    ],
                },
            },
            "overrides": [
                {
                    "matcher": {"id": "byName", "options": "Value"},
                    "properties": [
                        {"id": "custom.cellOptions", "value": {"type": "color-background"}},
                        {"id": "displayName", "value": "ok"},
                    ],
                }
            ],
        },
        "options": {
            "cellHeight": "sm",
            "footer": {"show": False},
            "showHeader": True,
            "sortBy": [{"desc": False, "displayName": "component_type"}],
        },
        "transformations": [
            {
                "id": "organize",
                "options": {
                    "excludeByName": {
                        "Time": True,
                        "__name__": True,
                        "agent_id": True,
                        "agent_type": True,
                        "cluster": True,
                        "environment": True,
                        "external_group": True,
                        "instance": True,
                        "job": True,
                        "node_id": True,
                        "node_name": True,
                        "node_type": True,
                        "service_id": True,
                        "service_name": True,
                        "service_type": True,
                    },
                    "indexByName": {
                        "component_type": 0,
                        "component": 1,
                        "health": 2,
                        "state": 3,
                        "detail": 4,
                        "Value": 5,
                    },
                    "renameByName": {
                        "component_type": "type",
                        "component": "component",
                        "health": "health",
                        "state": "state",
                        "detail": "detail",
                    },
                },
            }
        ],
    }


def build_dashboard():
    panels = []
    panel_id = 1

    stat_specs = [
        ("PostgreSQL up", zero_when_missing("sum(rental_patroni_up)"), 5),
        ("Primary", zero_when_missing("sum(rental_patroni_primary)"), 1),
        ("Sync standbys", zero_when_missing("max(rental_postgres_sync_standby_count)"), 2),
        ("etcd nodes", zero_when_missing("sum(rental_etcd_up)"), 5),
        ("HAProxy", zero_when_missing("sum(rental_haproxy_stats_up)"), 2),
        ("PgBouncer", zero_when_missing("sum(rental_pgbouncer_up)"), 2),
        ("Backup workers", zero_when_missing('sum(max by (service_name) (up{service_name=~"backup-worker-.*"}))'), 2),
        ("pgBackRest", zero_when_missing("max(rental_pgbackrest_info_up)"), 1),
    ]
    for idx, (title, expr, expected) in enumerate(stat_specs):
        panels.append(stat_panel(panel_id, title, expr, idx * 3, 0, 3, 4, expected=expected))
        panel_id += 1

    second_row = [
        ("Streaming replicas", zero_when_missing("max(rental_postgres_streaming_replica_count)"), 4, "short"),
        ("Replication lag", zero_when_missing("max(rental_postgres_replication_lag_bytes)"), None, "bytes"),
        ("MinIO", zero_when_missing("max(rental_minio_up)"), 1, "short"),
        ("WAL failures 15m", zero_when_missing("increase(rental_pg_wal_archiver_failed_count[15m])"), None, "short"),
    ]
    for idx, (title, expr, expected, unit) in enumerate(second_row):
        panel = stat_panel(panel_id, title, expr, idx * 6, 4, 6, 4, expected=expected, unit=unit)
        if title == "WAL failures 15m":
            panel["fieldConfig"]["defaults"]["thresholds"] = thresholds_green_until(1)
        if title == "Replication lag":
            panel["fieldConfig"]["defaults"]["thresholds"] = thresholds_for_lag_bytes()
        panels.append(panel)
        panel_id += 1

    panels.append(
        table_panel(
            panel_id,
            "Tracked components state",
            "rental_component_state",
            0,
            8,
            24,
            8,
        )
    )
    panel_id += 1

    panels.append(
        timeseries_panel(
            panel_id,
            "Roles and synchronous replication",
            [
                target("rental_patroni_primary", "primary {{node}}", "A"),
                target("rental_patroni_replica", "replica {{node}}", "B"),
                target("rental_postgres_sync_standby_count", "sync standbys", "C"),
                target("rental_postgres_streaming_replica_count", "streaming replicas", "D"),
            ],
            0,
            16,
            12,
            8,
        )
    )
    panel_id += 1

    panels.append(
        timeseries_panel(
            panel_id,
            "Replication and WAL archive",
            [
                target("rental_postgres_replication_lag_bytes", "lag bytes", "A"),
                target("rental_pg_wal_archiver_last_archive_age_seconds", "last WAL archive age", "B"),
                target("increase(rental_pg_wal_archiver_failed_count[15m])", "WAL failures 15m", "C"),
            ],
            12,
            16,
            12,
            8,
        )
    )
    panel_id += 1

    panels.append(
        timeseries_panel(
            panel_id,
            "Client access",
            [
                target("rental_haproxy_stats_up", "HAProxy {{client}}", "A"),
                target("rental_pgbouncer_up", "PgBouncer {{client}}", "B"),
                target("sum by (client) (rental_pgbouncer_cl_active)", "active clients {{client}}", "C"),
                target("sum by (client) (rental_pgbouncer_cl_waiting)", "waiting clients {{client}}", "D"),
            ],
            0,
            24,
            12,
            8,
        )
    )
    panel_id += 1

    panels.append(
        timeseries_panel(
            panel_id,
            "Backup contour",
            [
                target('up{service_name=~"backup-worker-.*"}', "scrape {{service_name}}", "A"),
                target("rental_backup_worker_pgbackrest_info_up", "worker pgBackRest {{worker}}", "B"),
                target("rental_backup_worker_backup_count", "worker backup count {{worker}}", "C"),
                target("rental_pgbackrest_info_up", "custom exporter pgBackRest", "D"),
                target("time() - max(rental_pgbackrest_latest_full_backup_stop_timestamp) or vector(-1)", "latest full backup age", "E"),
            ],
            12,
            24,
            12,
            8,
        )
    )
    panel_id += 1

    panels.append(
        timeseries_panel(
            panel_id,
            "PostgreSQL activity",
            [
                target('sum by (service_name) (pg_stat_database_numbackends{service_name=~"postgres-node-.*"})', "connections {{service_name}}", "A"),
                target('sum by (service_name) (rate(pg_stat_database_xact_commit{service_name=~"postgres-node-.*"}[5m]))', "commits/s {{service_name}}", "B"),
                target('sum by (service_name) (pg_locks_count{service_name=~"postgres-node-.*"})', "locks {{service_name}}", "C"),
            ],
            0,
            32,
            12,
            8,
        )
    )
    panel_id += 1

    panels.append(
        timeseries_panel(
            panel_id,
            "Consensus and infrastructure",
            [
                target("rental_etcd_up", "etcd {{node}}", "A"),
                target("rental_minio_up", "MinIO", "B"),
                target('up{service_name="rental-custom-observability"}', "custom exporter scrape", "C"),
                target("rental_custom_exporter_scrape_timestamp", "custom exporter scrape timestamp", "D"),
            ],
            12,
            32,
            12,
            8,
        )
    )

    return {
        "uid": DASHBOARD_UID,
        "title": "Rental HA Overview",
        "tags": ["rental-ha", "overview", "pmm"],
        "timezone": "browser",
        "schemaVersion": 39,
        "version": 1,
        "refresh": "10s",
        "time": {"from": "now-30m", "to": "now"},
        "panels": panels,
    }


def main():
    wait_for_grafana()
    payload = {"dashboard": build_dashboard(), "overwrite": True, "message": "Provision rental HA overview"}
    result = api_request("POST", "/dashboards/db", payload)
    uid = result.get("uid", DASHBOARD_UID)
    details = api_request("GET", f"/dashboards/uid/{uid}")
    dashboard_id = details.get("dashboard", {}).get("id")
    preferences = {"timezone": "browser", "homeDashboardUID": uid}
    if dashboard_id:
        preferences["homeDashboardId"] = dashboard_id

    try:
        api_request("PUT", "/org/preferences", preferences)
    except HTTPError:
        if dashboard_id:
            api_request("PUT", "/org/preferences", {"timezone": "browser", "homeDashboardId": dashboard_id})
        else:
            raise

    print(f"[pmm-dashboard] dashboard provisioned: {uid}")


if __name__ == "__main__":
    main()
