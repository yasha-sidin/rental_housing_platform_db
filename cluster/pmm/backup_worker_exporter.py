#!/usr/bin/env python3
import json
import os
import subprocess
import time
from http.server import BaseHTTPRequestHandler, HTTPServer


def metric(name, value, labels=None):
    label_text = ""
    if labels:
        pairs = [f'{key}="{str(val).replace(chr(34), chr(92) + chr(34))}"' for key, val in labels.items()]
        label_text = "{" + ",".join(pairs) + "}"
    return f"{name}{label_text} {value}"


def command_output(args, timeout=20):
    completed = subprocess.run(
        args,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout,
    )
    return completed.stdout


def collect_metrics():
    worker = os.environ.get("BACKUP_WORKER_NAME", "backup-worker")
    stanza_name = os.environ.get("PGBACKREST_STANZA", "rental")
    labels = {"worker": worker, "stanza": stanza_name}
    lines = [
        "# HELP rental_backup_worker_up Backup worker exporter availability.",
        "# TYPE rental_backup_worker_up gauge",
        metric("rental_backup_worker_up", 1, labels),
    ]

    try:
        output = command_output(["pgbackrest", f"--stanza={stanza_name}", "info", "--output=json"])
        data = json.loads(output)
        stanza = data[0] if data else {}
        backups = []
        for repo in stanza.get("repo", []):
            backups.extend(repo.get("backup", []))

        lines.append(metric("rental_backup_worker_pgbackrest_info_up", 1, labels))
        lines.append(metric("rental_backup_worker_backup_count", len(backups), labels))

        full_backups = [backup for backup in backups if backup.get("type") == "full"]
        if full_backups:
            latest = max(full_backups, key=lambda item: item.get("timestamp", {}).get("stop", 0))
            lines.append(
                metric(
                    "rental_backup_worker_latest_full_backup_stop_timestamp",
                    latest.get("timestamp", {}).get("stop", 0),
                    labels,
                )
            )
    except Exception:
        lines.append(metric("rental_backup_worker_pgbackrest_info_up", 0, labels))

    lines.append(metric("rental_backup_worker_scrape_timestamp", int(time.time()), labels))
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
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        return


if __name__ == "__main__":
    port = int(os.environ.get("BACKUP_WORKER_EXPORTER_PORT", "9190"))
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()
