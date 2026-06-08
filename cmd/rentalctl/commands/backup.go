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
			Short: "Run full backup and print pgBackRest output",
			RunE: func(cmd *cobra.Command, args []string) error {
				ctx, cancel := context.WithTimeout(cmd.Context(), 2*time.Hour)
				defer cancel()
				return fullBackup(ctx)
			},
		},
		&cobra.Command{
			Use:   "check",
			Short: "Run pgBackRest check and print output",
			RunE: func(cmd *cobra.Command, args []string) error {
				ctx, cancel := context.WithTimeout(cmd.Context(), 30*time.Minute)
				defer cancel()
				return capturePgBackRestArtifact(ctx, "pgbackrest_check.txt", `pgbackrest --stanza=rental --pg1-user="$POSTGRES_USER" check`)
			},
		},
	)

	return cmd
}

func fullBackup(ctx context.Context) error {
	if err := capturePgBackRestArtifact(ctx, "pgbackrest_full_backup.txt", `pgbackrest --stanza=rental --pg1-user="$POSTGRES_USER" --type=full backup`); err != nil {
		return err
	}
	return capturePgBackRestArtifact(ctx, "pgbackrest_info.txt", `pgbackrest --stanza=rental info`)
}

func capturePgBackRestArtifact(ctx context.Context, fileName string, command string) error {
	out, err := capturePgBackRestOnPrimary(ctx, command)
	if err != nil {
		return err
	}
	return util.PrintArtifact("09-backup", fileName, out)
}

func captureComposeArtifact(ctx context.Context, scenario string, fileName string, args ...string) error {
	out, err := util.DockerComposeCapture(ctx, args...)
	if err != nil {
		return err
	}
	return util.PrintArtifact(scenario, fileName, out)
}
