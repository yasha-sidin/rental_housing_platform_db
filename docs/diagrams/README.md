# Diagrams

Финальные схемы должны быть PNG 16:9, минимум 1920x1080.

Плановые файлы:

```text
docs/diagrams/png/01_overall_architecture.png
docs/diagrams/png/02_postgresql_ha_contour.png
docs/diagrams/png/03_client_proxy_contour.png
docs/diagrams/png/04_client_read_modes.png
docs/diagrams/png/05_backup_pitr_contour.png
docs/diagrams/png/06_failure_scenarios.png
docs/diagrams/png/07_production_requirements.png
docs/diagrams/png/08_observability_contour.png
```

Назначение схем:

- `01_overall_architecture.png` - общая архитектура стенда.
- `02_postgresql_ha_contour.png` - PostgreSQL/Patroni, etcd и синхронная запись.
- `03_client_proxy_contour.png` - независимые клиентские цепочки PgBouncer и HAProxy.
- `04_client_read_modes.png` - обычное чтение с реплик и строгое чтение после записи.
- `05_backup_pitr_contour.png` - резервное копирование, WAL archive, MinIO и PITR.
- `06_failure_scenarios.png` - основные сценарии отказа для защиты.
- `07_production_requirements.png` - требования к реальной production-системе.
- `08_observability_contour.png` - контур наблюдаемости через Percona Monitoring and Management.

Технические подписи и стрелки нужно контролировать вручную, потому что генеративная модель может искажать текст.
