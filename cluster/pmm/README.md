# Percona Monitoring and Management

Percona Monitoring and Management используется как контур наблюдаемости. Он не участвует в выборе основного PostgreSQL-узла и не является частью механизма автоматического переключения.

## Доступ

Percona Monitoring and Management открывается на `http://localhost:8080/graph/login`.

Учетные данные задаются через локальный `.env`; шаблон переменных хранится в корневом `.env.example`:

```env
PMM_ADMIN_USER=admin
PMM_ADMIN_PASSWORD=pmm_admin_local_demo
```

Docker Compose передает эти значения в Percona Monitoring and Management Server как переменные Grafana:

```yaml
GF_SECURITY_ADMIN_USER
GF_SECURITY_ADMIN_PASSWORD
```

При старте `cluster/pmm/register-services.sh` дополнительно синхронизирует пароль встроенного пользователя `admin` с `PMM_ADMIN_PASSWORD`. Это нужно для повторных запусков с уже существующим volume `pmm_data`.

## Регистрация сервисов

Percona Monitoring and Management Server запускает `cluster/pmm/register-services.sh` после готовности собственного веб-интерфейса. Скрипт регистрирует:

- пять PostgreSQL-узлов через штатный `postgres_exporter`;
- пять Patroni REST `/metrics` endpoints как внешние Prometheus endpoints;
- два HAProxy через Prometheus endpoint `/metrics`;
- пять etcd-узлов как внешние Prometheus endpoints;
- два `backup-worker` как внешние Prometheus endpoints;
- `pmm-custom-exporter` как внешний exporter для дополнительных метрик проекта.

Регистрация идемпотентна: если сервис уже есть в inventory Percona Monitoring and Management, повторный запуск его не дублирует.

Штатный дашборд Percona Monitoring and Management `PostgreSQL Patroni Details` использует отдельные Patroni-сервисы. Для него нужно выбирать `Service Name` вида `patroni-postgres-node-1` и `Scope Name` = `rental-ha`. При пустых значениях этих переменных дашборд не сможет найти `patroni_*` метрики.

## Главный дашборд

После регистрации сервисов Percona Monitoring and Management Server запускает `cluster/pmm/provision-dashboard.py`. Скрипт создает или обновляет дашборд `Rental HA Overview` и назначает его домашним экраном Grafana.

Дашборд собирает на одном экране:

- доступность пяти PostgreSQL-узлов;
- текущий основной узел и количество реплик;
- количество синхронных standby-узлов;
- доступность пяти etcd-узлов и риск потери кворума;
- состояние HAProxy и PgBouncer для обеих клиентских цепочек;
- состояние контейнеров `backup-worker-a` и `backup-worker-b`;
- доступность MinIO и состояние pgBackRest-репозитория;
- признаки WAL-архивирования и ошибок архивации;
- базовую активность PostgreSQL: соединения, commits/s и блокировки.
- таблицу состояния всех отслеживаемых компонентов.

## Дополнительный exporter проекта

`cluster/pmm/custom_exporter.py` поднимается отдельным контейнером `pmm-custom-exporter` и отдает метрики на `http://pmm-custom-exporter:9187/metrics`.

Он покрывает то, что не добавляется штатной командой Percona Monitoring and Management:

- состояние Patroni REST API по каждому PostgreSQL-узлу;
- текущую роль узла через проверки `/primary` и `/replica`;
- агрегированную таблицу `rental_component_state` для главного дашборда;
- доступность etcd `/health`;
- доступность MinIO;
- доступность HAProxy stats endpoint;
- количество streaming-реплик, количество синхронных standby-узлов и задержку репликации по данным текущего основного PostgreSQL-узла;
- счетчики архивации WAL из `pg_stat_archiver`;
- состояние пулов PgBouncer через административную базу `pgbouncer`;
- состояние репозитория pgBackRest через `pgbackrest info --output=json`;
- наличие и время последней полной резервной копии, если она уже создана.

`cluster/pmm/backup_worker_exporter.py` запускается внутри `backup-worker-a` и `backup-worker-b`. Он показывает, что конкретный исполнитель резервного копирования доступен для Percona Monitoring and Management и что из него выполняется `pgbackrest info --output=json`.

## Границы

Percona Monitoring and Management 3.8.0 в используемом образе не содержит штатной команды `pmm-admin add pgbouncer`. Поэтому PgBouncer контролируется custom exporter через административные SQL-команды `SHOW POOLS`.

Контур резервного копирования также не имеет готового интегратора Percona Monitoring and Management в этой конфигурации. Его состояние контролируется custom exporter через pgBackRest, S3-совместимый репозиторий и отдельные endpoints контейнеров `backup-worker-a/b`.
