package main

import (
	"context"
	"fmt"
	"time"

	"github.com/spf13/cobra"

	"rental-housing-platform-db/internal/pg"
	"rental-housing-platform-db/internal/runner"
)

func newClusterCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "cluster",
		Short: "Manage the Docker HA cluster",
	}

	cmd.AddCommand(
		&cobra.Command{
			Use:   "up",
			Short: "Build and start the cluster",
			RunE: func(cmd *cobra.Command, args []string) error {
				ctx, cancel := context.WithTimeout(cmd.Context(), 30*time.Minute)
				defer cancel()
				return clusterUp(ctx)
			},
		},
		&cobra.Command{
			Use:   "clear",
			Short: "Clear demo data without deleting the cluster",
			RunE: func(cmd *cobra.Command, args []string) error {
				ctx, cancel := context.WithTimeout(cmd.Context(), 10*time.Minute)
				defer cancel()
				return runner.DockerCompose(ctx, pg.PSQLArgs([]string{"-f", "/workspace/db/seeds/999_cleanup.sql"})...)
			},
		},
		&cobra.Command{
			Use:   "down",
			Short: "Delete containers, volumes and local cluster state",
			RunE: func(cmd *cobra.Command, args []string) error {
				ctx, cancel := context.WithTimeout(cmd.Context(), 30*time.Minute)
				defer cancel()
				return runner.DockerCompose(ctx, "down", "--volumes", "--remove-orphans")
			},
		},
	)

	return cmd
}

func clusterUp(ctx context.Context) error {
	startedAt := time.Now()
	logInfo("cluster up started")
	logInfo("running docker compose up -d --build")
	if err := runner.DockerCompose(ctx, "up", "-d", "--build"); err != nil {
		return err
	}

	logInfo("waiting for at least 2 synchronous standbys")
	if err := waitForSyncStandbys(ctx); err != nil {
		return err
	}

	logInfo("ensuring application database exists")
	if err := ensureDatabase(ctx); err != nil {
		return err
	}

	logInfo("cluster is ready in %s", time.Since(startedAt).Round(time.Second))
	return nil
}

func waitForSyncStandbys(ctx context.Context) error {
	deadline := time.Now().Add(5 * time.Minute)
	attempt := 1

	for time.Now().Before(deadline) {
		out, err := runner.DockerComposeCapture(ctx, "run", "--rm", "--no-deps", "postgres-client", "sh", "-ec", `PGPASSWORD="$POSTGRES_PASSWORD" psql -h haproxy -p 5000 -U "$POSTGRES_USER" -d postgres -tAc "select count(*) from pg_stat_replication where sync_state = 'sync';"`)
		if err == nil {
			if count, ok := lastIntegerLine(out); ok {
				logInfo("sync standbys: %d/2", count)
				if count >= 2 {
					return nil
				}
			} else {
				logInfo("sync standby check #%d returned unexpected output", attempt)
			}
		} else {
			logInfo("sync standby check #%d is not ready yet: %s", attempt, compactError(err))
		}

		attempt++
		time.Sleep(5 * time.Second)
	}

	return fmt.Errorf("timed out waiting for two synchronous standbys")
}

func ensureDatabase(ctx context.Context) error {
	command := `if [ "$POSTGRES_DB" = "postgres" ]; then exit 0; fi
if PGPASSWORD="$POSTGRES_PASSWORD" psql -h haproxy -p 5000 -U "$POSTGRES_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$POSTGRES_DB'" | grep -q 1; then exit 0; fi
PGPASSWORD="$POSTGRES_PASSWORD" createdb -h haproxy -p 5000 -U "$POSTGRES_USER" "$POSTGRES_DB"`

	return runner.DockerCompose(ctx, "run", "--rm", "--no-deps", "postgres-client", "sh", "-ec", command)
}
