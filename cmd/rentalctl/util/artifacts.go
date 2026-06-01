package util

import (
	"os"
	"path/filepath"
)

func WriteScenarioNote(scenario string, text string) error {
	return WriteArtifact(scenario, "next_steps.txt", text)
}

func WriteArtifact(scenario string, name string, content string) error {
	path := filepath.Join("demo", scenario, "artifacts", name)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(content), 0o644)
}
