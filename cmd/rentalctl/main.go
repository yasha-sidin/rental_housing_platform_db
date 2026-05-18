package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

func main() {
	if err := newRootCommand().Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func newRootCommand() *cobra.Command {
	root := &cobra.Command{
		Use:   "rentalctl",
		Short: "Manage the rental housing PostgreSQL HA demo",
	}

	root.AddCommand(
		newClusterCommand(),
		newVerifyCommand(),
		newDemoCommand(),
		newBackupCommand(),
		newMigrateCommand(),
		newMigrateContainerCommand(),
		newMigratePrepareCommand(),
		newSeedgenCommand(),
	)

	return root
}
