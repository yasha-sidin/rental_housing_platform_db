# PMM

PMM используется как контур наблюдаемости, а не как часть механизма failover.

В демонстрации PMM должен показать:

- состояние PostgreSQL-узлов;
- нагрузку CPU/RAM/disk/network;
- connections, transactions, locks, checkpoints;
- WAL и replication metrics;
- HAProxy endpoints;
- динамику во время failover и backup/PITR-сценариев.

Подключение PMM clients/exporters выполняется после стабилизации HA-кластера, чтобы не смешивать демонстрацию отказоустойчивости и настройку наблюдаемости.
