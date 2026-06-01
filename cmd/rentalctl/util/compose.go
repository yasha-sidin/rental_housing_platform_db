package util

import "context"

func DockerCompose(ctx context.Context, args ...string) error {
	fullArgs := append([]string{"compose"}, args...)
	return RunCommand(ctx, "docker", fullArgs...)
}

func DockerComposeCapture(ctx context.Context, args ...string) (string, error) {
	fullArgs := append([]string{"compose"}, args...)
	return CaptureCommand(ctx, "docker", fullArgs...)
}
