package runner

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func Run(ctx context.Context, name string, args ...string) error {
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

func Capture(ctx context.Context, name string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	out, err := cmd.CombinedOutput()

	if err != nil {
		message := strings.TrimSpace(string(out))
		if message == "" {
			message = err.Error()
		}
		return string(out), fmt.Errorf("%s: %w", message, err)
	}

	return string(out), nil
}

func DockerCompose(ctx context.Context, args ...string) error {
	fullArgs := append([]string{"compose"}, args...)
	return Run(ctx, "docker", fullArgs...)
}

func DockerComposeCapture(ctx context.Context, args ...string) (string, error) {
	fullArgs := append([]string{"compose"}, args...)
	return Capture(ctx, "docker", fullArgs...)
}
