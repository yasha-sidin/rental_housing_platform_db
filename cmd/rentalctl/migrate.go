package main

import (
	"context"
	"fmt"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"rental-housing-platform-db/internal/runner"
)

type prepareOptions struct {
	sourceUpDir   string
	sourceDownDir string
	outputDir     string
	checkOnly     bool
}

func newMigrateCommand() *cobra.Command {
	return &cobra.Command{
		Use:                "migrate <args...>",
		Short:              "Run golang-migrate through the migration runner container",
		Args:               cobra.MinimumNArgs(1),
		DisableFlagParsing: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx, cancel := context.WithTimeout(cmd.Context(), 30*time.Minute)
			defer cancel()
			return runMigration(ctx, args...)
		},
	}
}

func newMigrateContainerCommand() *cobra.Command {
	return &cobra.Command{
		Use:                "migrate-container <args...>",
		Short:              "Run migrate inside the migration runner container",
		Hidden:             true,
		Args:               cobra.MinimumNArgs(1),
		DisableFlagParsing: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx, cancel := context.WithTimeout(cmd.Context(), 30*time.Minute)
			defer cancel()
			return migrateContainer(ctx, args...)
		},
	}
}

func newMigratePrepareCommand() *cobra.Command {
	opts := prepareOptions{
		sourceUpDir:   "/workspace/db/migrations",
		sourceDownDir: "/workspace/db/rollback",
		outputDir:     "/tmp/migrations",
	}

	cmd := &cobra.Command{
		Use:    "migrate-prepare",
		Short:  "Prepare V/U migrations for golang-migrate",
		Hidden: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			return prepareMigrations(opts)
		},
	}

	cmd.Flags().StringVar(&opts.sourceUpDir, "source-up", opts.sourceUpDir, "directory with V*.sql migrations")
	cmd.Flags().StringVar(&opts.sourceDownDir, "source-down", opts.sourceDownDir, "directory with U*.sql migrations")
	cmd.Flags().StringVar(&opts.outputDir, "output", opts.outputDir, "output directory for golang-migrate files")
	cmd.Flags().BoolVar(&opts.checkOnly, "check-only", false, "validate migration pairs without writing files")

	return cmd
}

func runMigration(ctx context.Context, args ...string) error {
	composeArgs := append([]string{"run", "--rm", "--no-deps", "migration_runner", "rentalctl", "migrate-container"}, args...)
	return runner.DockerCompose(ctx, composeArgs...)
}

func captureMigration(ctx context.Context, args ...string) (string, error) {
	composeArgs := append([]string{"run", "--rm", "--no-deps", "migration_runner", "rentalctl", "migrate-container"}, args...)
	return runner.DockerComposeCapture(ctx, composeArgs...)
}

func migrateContainer(ctx context.Context, args ...string) error {
	opts := prepareOptions{
		sourceUpDir:   envOrDefault("SOURCE_UP_DIR", "/workspace/db/migrations"),
		sourceDownDir: envOrDefault("SOURCE_DOWN_DIR", "/workspace/db/rollback"),
		outputDir:     envOrDefault("OUTPUT_DIR", "/tmp/migrations"),
	}
	if err := prepareMigrations(opts); err != nil {
		return err
	}

	dsn, err := databaseURL()
	if err != nil {
		return err
	}

	migrateArgs := append([]string{"-path", opts.outputDir, "-database", dsn}, args...)
	return runner.Run(ctx, "migrate", migrateArgs...)
}

func prepareMigrations(opts prepareOptions) error {
	upFiles, err := migrationFiles(opts.sourceUpDir, `^V([0-9]+)__(.+)\.sql$`)
	if err != nil {
		return err
	}
	if len(upFiles) == 0 {
		return fmt.Errorf("no V*.sql files found in %s", opts.sourceUpDir)
	}

	downFiles, err := migrationFiles(opts.sourceDownDir, `^U([0-9]+)__(.+)\.sql$`)
	if err != nil {
		return err
	}

	downByVersion := make(map[string]migrationFile, len(downFiles))
	for _, file := range downFiles {
		if _, exists := downByVersion[file.version]; exists {
			return fmt.Errorf("more than one down migration found for version %s", file.version)
		}
		downByVersion[file.version] = file
	}

	if !opts.checkOnly {
		if err := os.RemoveAll(opts.outputDir); err != nil {
			return err
		}
		if err := os.MkdirAll(opts.outputDir, 0o755); err != nil {
			return err
		}
	}

	for _, up := range upFiles {
		down, ok := downByVersion[up.version]
		if !ok {
			return fmt.Errorf("no down migration found for version %s (%s)", up.version, up.name)
		}

		version, err := strconv.Atoi(strings.TrimLeft(up.version, "0"))
		if err != nil {
			return fmt.Errorf("invalid migration version %s: %w", up.version, err)
		}
		baseName := fmt.Sprintf("%03d_%s", version, up.name)

		if !opts.checkOnly {
			if err := copyFile(up.path, filepath.Join(opts.outputDir, baseName+".up.sql")); err != nil {
				return err
			}
			if err := copyFile(down.path, filepath.Join(opts.outputDir, baseName+".down.sql")); err != nil {
				return err
			}
		}
	}

	for _, down := range downFiles {
		found := false
		for _, up := range upFiles {
			if up.version == down.version {
				found = true
				break
			}
		}
		if !found {
			return fmt.Errorf("down migration has no matching up migration: %s", filepath.Base(down.path))
		}
	}

	if opts.checkOnly {
		fmt.Fprintln(os.Stdout, "OK: migration pairs are valid")
	} else {
		fmt.Fprintf(os.Stdout, "OK: migrations prepared in %s\n", opts.outputDir)
	}
	return nil
}

type migrationFile struct {
	path    string
	version string
	name    string
}

func migrationFiles(dir string, pattern string) ([]migrationFile, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("read migrations from %s: %w", dir, err)
	}

	re := regexp.MustCompile(pattern)
	files := make([]migrationFile, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		matches := re.FindStringSubmatch(entry.Name())
		if matches == nil {
			continue
		}
		files = append(files, migrationFile{
			path:    filepath.Join(dir, entry.Name()),
			version: matches[1],
			name:    matches[2],
		})
	}

	sort.Slice(files, func(i, j int) bool {
		return files[i].path < files[j].path
	})
	return files, nil
}

func copyFile(source string, target string) error {
	data, err := os.ReadFile(source)
	if err != nil {
		return err
	}
	return os.WriteFile(target, data, 0o644)
}

func databaseURL() (string, error) {
	user := os.Getenv("POSTGRES_USER")
	password := os.Getenv("POSTGRES_PASSWORD")
	dbName := os.Getenv("POSTGRES_DB")
	if user == "" || password == "" || dbName == "" {
		return "", fmt.Errorf("POSTGRES_USER, POSTGRES_PASSWORD and POSTGRES_DB must be set")
	}

	host := envOrDefault("DB_HOST", "rental_housing_platform_db")
	port := envOrDefault("DB_PORT", "5432")
	sslMode := envOrDefault("DB_SSLMODE", "disable")

	u := url.URL{
		Scheme: "postgres",
		User:   url.UserPassword(user, password),
		Host:   net.JoinHostPort(host, port),
		Path:   dbName,
	}
	query := u.Query()
	query.Set("sslmode", sslMode)
	u.RawQuery = query.Encode()
	return u.String(), nil
}
