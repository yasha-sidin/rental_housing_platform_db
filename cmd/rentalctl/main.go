package main

import (
	"fmt"
	"os"

	"rental-housing-platform-db/cmd/rentalctl/commands"
)

func main() {
	if err := commands.NewRootCommand().Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
