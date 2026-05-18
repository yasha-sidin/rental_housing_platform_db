package main

import (
	"fmt"

	"github.com/spf13/cobra"
)

func newSeedgenCommand() *cobra.Command {
	return &cobra.Command{
		Use:   "seedgen",
		Short: "Print the planned seed generator placeholder",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Fprintln(cmd.OutOrStdout(), "-- seedgen placeholder")
			fmt.Fprintln(cmd.OutOrStdout(), "-- Mass seed generation will live here if SQL seeds become too large.")
		},
	}
}
