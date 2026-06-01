package commands

import "github.com/spf13/cobra"

func NewRootCommand() *cobra.Command {
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
