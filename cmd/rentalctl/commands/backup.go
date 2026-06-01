package commands

import (
	"context"
	"time"

	"github.com/spf13/cobra"

	"rental-housing-platform-db/cmd/rentalctl/util"
)

func newBackupCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "backup",
		Short: "Run pgBackRest backup checks",
	}

	cmd.AddCommand(
		&cobra.Command{
			Use:   "full",
			Short: "Run full backup and save artifacts",
			RunE: func(cmd *cobra.Command, args []string) error {
				ctx, cancel := context.WithTimeout(cmd.Context(), 2*time.Hour)
				defer cancel()
				return fullBackup(ctx)
			},
		},
		&cobra.Command{
			Use:   "check",
			Short: "Run pgBackRest check and save artifact",
			RunE: func(cmd *cobra.Command, args []string) error {
				ctx, cancel := context.WithTimeout(cmd.Context(), 30*time.Minute)
				defer cancel()
				return captureComposeArtifact(ctx, "06-backup", "pgbackrest_check.txt", "exec", "-T", "postgres-node-4", "pgbackrest", "--stanza=rental", "check")
			},
		},
	)

	return cmd
}

func fullBackup(ctx context.Context) error {
	if err := captureComposeArtifact(ctx, "06-backup", "pgbackrest_full_backup.txt", "exec", "-T", "postgres-node-4", "pgbackrest", "--stanza=rental", "--type=full", "backup"); err != nil {
		return err
	}
	return captureComposeArtifact(ctx, "06-backup", "pgbackrest_info.txt", "exec", "-T", "postgres-node-4", "pgbackrest", "--stanza=rental", "info")
}

func captureComposeArtifact(ctx context.Context, scenario string, fileName string, args ...string) error {
	out, err := util.DockerComposeCapture(ctx, args...)
	if err != nil {
		return err
	}
	return util.WriteArtifact(scenario, fileName, out)
}
