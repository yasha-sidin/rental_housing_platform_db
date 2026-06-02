package commands

import (
	"context"
	"fmt"

	"rental-housing-platform-db/cmd/rentalctl/util"
)

var postgresServices = []string{
	"postgres-node-1",
	"postgres-node-2",
	"postgres-node-3",
	"postgres-node-4",
	"postgres-node-5",
}

func currentPrimaryService(ctx context.Context) (string, error) {
	for _, service := range postgresServices {
		_, err := util.DockerComposeCapture(ctx, "exec", "-T", service, "sh", "-ec", "curl -fsS http://127.0.0.1:8008/primary >/dev/null")
		if err == nil {
			return service, nil
		}
	}

	return "", fmt.Errorf("unable to find current PostgreSQL primary")
}

func runPgBackRestOnPrimary(ctx context.Context, command string) error {
	primary, err := currentPrimaryService(ctx)
	if err != nil {
		return err
	}

	return util.DockerCompose(ctx, "exec", "-T", primary, "sh", "-ec", command)
}

func capturePgBackRestOnPrimary(ctx context.Context, command string) (string, error) {
	primary, err := currentPrimaryService(ctx)
	if err != nil {
		return "", err
	}

	return util.DockerComposeCapture(ctx, "exec", "-T", primary, "sh", "-ec", command)
}
