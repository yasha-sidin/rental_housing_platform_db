package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

func envOrDefault(name string, fallback string) string {
	value := os.Getenv(name)
	if value == "" {
		return fallback
	}
	return value
}

func logInfo(format string, args ...any) {
	fmt.Fprintf(os.Stdout, "[rentalctl] "+format+"\n", args...)
}

func compactError(err error) string {
	text := strings.TrimSpace(err.Error())
	if text == "" {
		return "unknown error"
	}
	lines := strings.Split(text, "\n")
	return strings.TrimSpace(lines[0])
}

func lastIntegerLine(text string) (int, bool) {
	lines := strings.Split(text, "\n")
	for i := len(lines) - 1; i >= 0; i-- {
		line := strings.TrimSpace(lines[i])
		if line == "" {
			continue
		}
		value, err := strconv.Atoi(line)
		if err == nil {
			return value, true
		}
	}
	return 0, false
}
