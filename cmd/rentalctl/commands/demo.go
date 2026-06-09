package commands

import (
	"bytes"
	"context"
	"fmt"
	"time"

	"github.com/spf13/cobra"

	"rental-housing-platform-db/cmd/rentalctl/seedgen"
	"rental-housing-platform-db/cmd/rentalctl/util"
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
	case "analytics", "mass-analytics":
		return runMassAnalyticsDemo(ctx)
	case "failover":
		return util.PrintScenarioNote("05-failover", "Остановить текущий primary, дождаться нового primary через маршрут записи HAProxy, сохранить вывод Patroni/HAProxy и успешную запись после failover.\n")
	case "proxy":
		return util.PrintScenarioNote("06-proxy-failure", "Остановить pgbouncer-client-a или haproxy-client-a, показать, что клиент B продолжает работать через свою цепочку PgBouncer + HAProxy. Сохранить docker compose ps и успешный SQL-запрос клиента B.\n")
	case "rpo-zero":
		return util.PrintScenarioNote("07-sync-rpo-zero", "Записать подтвержденную транзакцию, остановить primary, после failover прочитать запись на новом primary. Отдельно показать остановку записи при нехватке двух synchronous replicas.\n")
	case "etcd-quorum", "etcd":
		return util.PrintScenarioNote("08-etcd-quorum", "Остановить три etcd-узла, показать потерю кворума 2/5, подождать 40-60 секунд реакции Patroni и проверить отказ новой записи через write-route. После скрина вернуть etcd-узлы и проверить восстановление маршрута записи.\n")
	case "backup":
		return fullBackup(ctx)
	case "pitr":
		return util.PrintScenarioNote("10-pitr", "Создать restore point, выполнить логическую ошибку, восстановить recovery-node из full backup и WAL archive до момента перед ошибкой, сохранить проверочные SELECT.\n")
	case "observability":
		return util.PrintScenarioNote("11-observability", "Открыть Percona Monitoring and Management на http://localhost:8080, сохранить dashboard состояния PostgreSQL, HAProxy, etcd и backup-контура.\n")
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
	return util.PrintArtifact("02-migration", "migration_version.txt", out)
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
		if err := util.DockerCompose(ctx, util.PostgresClientPSQLArgs([]string{"-f", file})...); err != nil {
			return err
		}
	}

	out, err := util.DockerComposeCapture(ctx, util.PostgresClientPSQLArgs([]string{`-c "select 'users' as entity, count(*) from application.users union all select 'listings', count(*) from application.listings union all select 'bookings', count(*) from application.bookings order by entity;"`})...)
	if err != nil {
		return err
	}
	return util.PrintArtifact("03-domain", "domain_counts.txt", out)
}

func runMassAnalyticsDemo(ctx context.Context) error {
	if err := util.DockerCompose(ctx, util.PostgresClientPSQLArgs([]string{"-f", "/workspace/db/seeds/001_reference.sql"})...); err != nil {
		return err
	}

	var seedSQL bytes.Buffer
	if err := seedgen.Generate(&seedSQL, seedgen.Options{
		Rows:           200,
		DaysPerListing: 14,
		Prefix:         "Seed",
	}); err != nil {
		return err
	}

	if err := util.PrintArtifact("04-mass-analytics", "mass_generation_apply.txt", "Applying generated seed SQL: rows=200 days_per_listing=14 prefix=Seed\n"); err != nil {
		return err
	}

	if err := util.DockerComposeWithInput(
		ctx,
		seedSQL.String(),
		"run",
		"--rm",
		"-T",
		"--no-deps",
		"postgres-client",
		"sh",
		"-ec",
		`PGPASSWORD="$POSTGRES_PASSWORD" psql -h haproxy-client-a -p 5000 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1`,
	); err != nil {
		return err
	}

	countsQuery := `-c "select 'generated_users' as entity, count(*) from application.users where username like 'Seed\_%' escape '\' union all select 'generated_listings', count(*) from application.listings where description like 'Seed listing #%'
union all select 'generated_bookings', count(*) from application.bookings b join application.listings l on l.id = b.listing_id where l.description like 'Seed listing #%'
order by entity;"`
	out, err := util.DockerComposeCapture(ctx, util.PostgresClientPSQLArgs([]string{countsQuery})...)
	if err != nil {
		return err
	}
	if err := util.PrintArtifact("04-mass-analytics", "mass_generation_counts.txt", out); err != nil {
		return err
	}

	if err := util.PrintArtifact("04-mass-analytics", "analytics_queries.txt", "Running analytical scenarios 01-booking-payment-review-report and 02-listing-description-regex\n"); err != nil {
		return err
	}

	files := []string{
		"/workspace/scenarios/analytical/01-booking-payment-review-report/request.sql",
		"/workspace/scenarios/analytical/02-listing-description-regex/request.sql",
	}
	for _, file := range files {
		if err := util.DockerCompose(ctx, util.PostgresClientPSQLArgs([]string{"-f", file})...); err != nil {
			return err
		}
	}

	return nil
}
