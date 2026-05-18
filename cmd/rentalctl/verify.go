package main

import (
	"context"
	"time"

	"github.com/spf13/cobra"

	"rental-housing-platform-db/internal/pg"
	"rental-housing-platform-db/internal/runner"
)

func newVerifyCommand() *cobra.Command {
	return &cobra.Command{
		Use:   "verify",
		Short: "Show container status and verify writer endpoint",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx, cancel := context.WithTimeout(cmd.Context(), 5*time.Minute)
			defer cancel()
			return verify(ctx)
		},
	}
}

func verify(ctx context.Context) error {
	if err := runner.DockerCompose(ctx, "ps"); err != nil {
		return err
	}

	query := `-c "select now() as checked_at, inet_server_addr() as server_addr, pg_is_in_recovery() as is_replica;"`
	return runner.DockerCompose(ctx, pg.PSQLArgs([]string{query})...)
}
