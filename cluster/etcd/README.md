# etcd

В стенде используется 5 etcd-узлов. Quorum равен 3, поэтому DCS-контур переживает отказ двух etcd-узлов.

etcd хранит состояние Patroni и leader lock. Он не хранит бизнес-данные платформы аренды.

Конфигурация каждого узла вынесена в отдельный файл:

```text
etcd-1.yml
etcd-2.yml
etcd-3.yml
etcd-4.yml
etcd-5.yml
```

В `docker-compose.yaml` остается только общий запуск `etcd --config-file=/etc/etcd/etcd.yml`, а конкретные параметры узла подключаются через volume.
