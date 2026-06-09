package util

import (
	"fmt"
	"os"
	"strings"
)

func PrintScenarioNote(scenario string, text string) error {
	return PrintArtifact(scenario, "next_steps.txt", text)
}

func PrintArtifact(scenario string, name string, content string) error {
	fmt.Fprintf(os.Stdout, "[rentalctl] %s/%s\n", scenario, name)
	if content != "" {
		fmt.Fprint(os.Stdout, content)
		if !strings.HasSuffix(content, "\n") {
			fmt.Fprintln(os.Stdout)
		}
	}
	return nil
}
