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
		return writeScenarioNote("03-failover", "РћСЃС‚Р°РЅРѕРІРёС‚СЊ С‚РµРєСѓС‰РёР№ primary, РґРѕР¶РґР°С‚СЊСЃСЏ РЅРѕРІРѕРіРѕ primary С‡РµСЂРµР· HAProxy writer endpoint, СЃРѕС…СЂР°РЅРёС‚СЊ РІС‹РІРѕРґ Patroni/HAProxy Рё СѓСЃРїРµС€РЅСѓСЋ Р·Р°РїРёСЃСЊ РїРѕСЃР»Рµ failover.\n")
	case "proxy":
		return writeScenarioNote("04-proxy-failure", "РћСЃС‚Р°РЅРѕРІРёС‚СЊ pgbouncer-client-a, РїРѕРєР°Р·Р°С‚СЊ, С‡С‚Рѕ pgbouncer-client-b РїСЂРѕРґРѕР»Р¶Р°РµС‚ СЂР°Р±РѕС‚Р°С‚СЊ. РЎРѕС…СЂР°РЅРёС‚СЊ docker compose ps Рё СѓСЃРїРµС€РЅС‹Р№ SQL-Р·Р°РїСЂРѕСЃ РєР»РёРµРЅС‚Р° B.\n")
	case "rpo-zero":
		return writeScenarioNote("05-sync-rpo-zero", "Р—Р°РїРёСЃР°С‚СЊ РїРѕРґС‚РІРµСЂР¶РґРµРЅРЅСѓСЋ С‚СЂР°РЅР·Р°РєС†РёСЋ, РѕСЃС‚Р°РЅРѕРІРёС‚СЊ primary, РїРѕСЃР»Рµ failover РїСЂРѕС‡РёС‚Р°С‚СЊ Р·Р°РїРёСЃСЊ РЅР° РЅРѕРІРѕРј primary. РћС‚РґРµР»СЊРЅРѕ РїРѕРєР°Р·Р°С‚СЊ РѕСЃС‚Р°РЅРѕРІРєСѓ Р·Р°РїРёСЃРё РїСЂРё РЅРµС…РІР°С‚РєРµ РґРІСѓС… synchronous replicas.\n")
	case "backup":
		return fullBackup(ctx)
	case "pitr":
		return writeScenarioNote("07-pitr", "РЎРѕР·РґР°С‚СЊ restore point, РІС‹РїРѕР»РЅРёС‚СЊ Р»РѕРіРёС‡РµСЃРєСѓСЋ РѕС€РёР±РєСѓ, РІРѕСЃСЃС‚Р°РЅРѕРІРёС‚СЊ recovery-node РёР· full backup Рё WAL archive РґРѕ РјРѕРјРµРЅС‚Р° РїРµСЂРµРґ РѕС€РёР±РєРѕР№, СЃРѕС…СЂР°РЅРёС‚СЊ РїСЂРѕРІРµСЂРѕС‡РЅС‹Рµ SELECT.\n")
	case "observability":
		return writeScenarioNote("08-observability", "РћС‚РєСЂС‹С‚СЊ PMM РЅР° http://localhost:8080, СЃРѕС…СЂР°РЅРёС‚СЊ dashboard СЃРѕСЃС‚РѕСЏРЅРёСЏ PostgreSQL/HAProxy РґРѕ Рё РїРѕСЃР»Рµ failover.\n")
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
