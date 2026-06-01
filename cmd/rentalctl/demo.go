package main

import (
	"context"
	"fmt"
	"time"

	"github.com/spf13/cobra"

	"rental-housing-platform-db/internal/pg"
	"rental-housing-platform-db/internal/runner"
)

func newDemoCommand() *cobra.Command {
	return &cobra.Command{
		Use:   "demo <scenario>",
		Short: "Run or prepare a demo scenario",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx, cancel := context.WithTimeout(cmd.Context(), 30*time.Minute)
			defer cancel()
			return demo(ctx, args[0])
		},
	}
}

func demo(ctx context.Context, scenario string) error {
	switch scenario {
	case "domain":
		return runDomainDemo(ctx)
	case "migration":
		return runMigrationDemo(ctx)
	case "failover":
		return writeScenarioNote("03-failover", "Остановить текущий primary, дождаться нового primary через маршрут записи HAProxy, сохранить вывод Patroni/HAProxy и успешную запись после failover.\n")
	case "proxy":
		return writeScenarioNote("04-proxy-failure", "Остановить pgbouncer-client-a или haproxy-client-a, показать, что клиент B продолжает работать через свою цепочку PgBouncer + HAProxy. Сохранить docker compose ps и успешный SQL-запрос клиента B.\n")
	case "rpo-zero":
		return writeScenarioNote("05-sync-rpo-zero", "Записать подтвержденную транзакцию, остановить primary, после failover прочитать запись на новом primary. Отдельно показать остановку записи при нехватке двух synchronous replicas.\n")
	case "backup":
		return fullBackup(ctx)
	case "pitr":
		return writeScenarioNote("07-pitr", "Создать restore point, выполнить логическую ошибку, восстановить recovery-node из full backup и WAL archive до момента перед ошибкой, сохранить проверочные SELECT.\n")
	case "observability":
		return writeScenarioNote("08-observability", "Открыть PMM на http://localhost:8080, сохранить dashboard состояния PostgreSQL и HAProxy до и после failover.\n")
	default:
		return fmt.Errorf("unknown scenario: %s", scenario)
	}
}

func runMigrationDemo(ctx context.Context) error {
	if err := runMigration(ctx, "up"); err != nil {
		return err
	}
	out, err := captureMigration(ctx, "version")
	if err != nil {
		return err
	}
	return writeArtifact("02-migration", "migration_version.txt", out)
}

func runDomainDemo(ctx context.Context) error {
	files := []string{
		"/workspace/db/seeds/001_reference.sql",
		"/workspace/db/seeds/002_demo_users_listings.sql",
		"/workspace/db/seeds/003_booking_scenarios.sql",
		"/workspace/db/seeds/004_pitr_scenario.sql",
		"/workspace/db/tests/001_domain_invariants.sql",
	}

	for _, file := range files {
		if err := runner.DockerCompose(ctx, pg.PSQLArgs([]string{"-f", file})...); err != nil {
			return err
		}
	}

	out, err := runner.DockerComposeCapture(ctx, pg.PSQLArgs([]string{`-c "select 'users' as entity, count(*) from application.users union all select 'listings', count(*) from application.listings union all select 'bookings', count(*) from application.bookings order by entity;"`})...)
	if err != nil {
		return err
	}
	return writeArtifact("01-domain", "domain_counts.txt", out)
}
