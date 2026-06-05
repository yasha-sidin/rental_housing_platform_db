# 08-observability

Раздел фиксирует проверку наблюдаемости кластера. Основной инструмент наблюдения - Percona Monitoring and Management с дашбордом `Rental HA Overview`, дополненный custom exporter-ом проекта.

## Полученные артефакты

- `artifacts/rental-ha-overview.png` - главный дашборд с агрегированным состоянием PostgreSQL, etcd, клиентских цепочек, MinIO и pgBackRest.
- `artifacts/rental-ha-overview-with-table.png` - главный дашборд с таблицей состояния всех отслеживаемых компонентов.
- `artifacts/rental-ha-overview-bottom.png` - нижняя часть дашборда с дополнительными метриками резервного контура и активности PostgreSQL.
- `artifacts/patroni-details.png` - специализированный дашборд Patroni для выбранного сервиса.

## Интерпретация

Артефакты показывают, что наблюдаемость покрывает не только PostgreSQL-узлы, но и компоненты, влияющие на эксплуатационную надежность: etcd, PgBouncer, HAProxy, MinIO, pgBackRest и рабочие контейнеры резервного копирования. Таблица состояния нужна как быстрый операционный обзор перед детальным анализом метрик.
