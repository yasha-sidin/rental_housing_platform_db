package commands

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"rental-housing-platform-db/cmd/rentalctl/seedgen"
	"rental-housing-platform-db/cmd/rentalctl/util"
)

func newSeedgenCommand() *cobra.Command {
	opts := seedgenCommandOptions{
		rows:           100,
		daysPerListing: 30,
		startDayOffset: 120,
		prefix:         "load",
		output:         "-",
	}

	cmd := &cobra.Command{
		Use:   "seedgen",
		Short: "Generate mass seed SQL",
		Long:  "Generate deterministic mass seed SQL for load-style domain data: users, listings, availability, bookings, payments, reviews and price history.",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx, cancel := context.WithTimeout(cmd.Context(), 30*time.Minute)
			defer cancel()
			return runSeedgen(ctx, cmd, opts)
		},
	}

	cmd.Flags().IntVar(&opts.rows, "rows", opts.rows, "number of generated owner/listing/guest groups")
	cmd.Flags().IntVar(&opts.daysPerListing, "days-per-listing", opts.daysPerListing, "number of availability days per generated listing")
	cmd.Flags().IntVar(&opts.startDayOffset, "start-day-offset", opts.startDayOffset, "first generated availability day offset from current_date")
	cmd.Flags().StringVar(&opts.prefix, "prefix", opts.prefix, "username and URL prefix for generated data")
	cmd.Flags().StringVarP(&opts.output, "output", "o", opts.output, "SQL output path, or - for stdout")
	cmd.Flags().BoolVar(&opts.apply, "apply", false, "write SQL to demo artifacts and apply it through postgres-client")

	return cmd
}

type seedgenCommandOptions struct {
	rows           int
	daysPerListing int
	startDayOffset int
	prefix         string
	output         string
	apply          bool
}

func runSeedgen(ctx context.Context, cmd *cobra.Command, opts seedgenCommandOptions) error {
	output := opts.output
	if opts.apply && output == "-" {
		output = filepath.Join("demo", "01-domain", "artifacts", "load_seed.sql")
	}

	generatorOptions := seedgen.Options{
		Rows:           opts.rows,
		DaysPerListing: opts.daysPerListing,
		StartDayOffset: opts.startDayOffset,
		Prefix:         opts.prefix,
	}

	if output == "-" {
		return seedgen.Generate(cmd.OutOrStdout(), generatorOptions)
	}

	if err := writeSeedFile(output, generatorOptions); err != nil {
		return err
	}
	fmt.Fprintf(cmd.OutOrStdout(), "Generated seed SQL: %s\n", output)

	if !opts.apply {
		return nil
	}

	containerPath, err := mountedContainerPath(output)
	if err != nil {
		return err
	}
	fmt.Fprintf(cmd.OutOrStdout(), "Applying seed SQL through postgres-client: %s\n", containerPath)
	return util.DockerCompose(ctx, util.PostgresClientPSQLArgs([]string{"-f", containerPath})...)
}

func writeSeedFile(path string, opts seedgen.Options) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}

	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()

	return seedgen.Generate(file, opts)
}

func mountedContainerPath(path string) (string, error) {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return "", err
	}
	absRoot, err := filepath.Abs(".")
	if err != nil {
		return "", err
	}

	relativePath, err := filepath.Rel(absRoot, absPath)
	if err != nil {
		return "", err
	}
	if relativePath == ".." || strings.HasPrefix(relativePath, ".."+string(filepath.Separator)) {
		return "", fmt.Errorf("--apply output must be inside the project directory")
	}

	slashPath := filepath.ToSlash(relativePath)
	switch {
	case strings.HasPrefix(slashPath, "demo/"):
		return "/workspace/" + slashPath, nil
	case strings.HasPrefix(slashPath, "db/seeds/"):
		return "/workspace/" + slashPath, nil
	default:
		return "", fmt.Errorf("--apply output must be inside demo/ or db/seeds/ because postgres-client mounts only those paths")
	}
}
