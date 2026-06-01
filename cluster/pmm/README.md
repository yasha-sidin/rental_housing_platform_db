# Percona Monitoring and Management

Percona Monitoring and Management используется как контур наблюдаемости, а не как часть механизма failover.

В демонстрации Percona Monitoring and Management должен показать:

- состояние PostgreSQL-узлов;
- нагрузку CPU, RAM, disk и network;
- connections, transactions, locks, checkpoints;
- WAL и replication metrics;
- endpoints двух HAProxy;
- динамику во время failover и backup/PITR-сценариев.

Подключение клиентов и exporters Percona Monitoring and Management выполняется после стабилизации HA-кластера, чтобы не смешивать демонстрацию отказоустойчивости и настройку наблюдаемости.
