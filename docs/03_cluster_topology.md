# Cluster Topology

## PostgreSQL HA-контур

Контур высокой доступности - часть архитектуры, отвечающая за непрерывную работу базы данных при отказе отдельных узлов.

```text
postgres-node-1: PostgreSQL + Patroni
postgres-node-2: PostgreSQL + Patroni
postgres-node-3: PostgreSQL + Patroni
postgres-node-4: PostgreSQL + Patroni
postgres-node-5: PostgreSQL + Patroni
```

Patroni управляет ролью узла, promotion и failover. PostgreSQL хранит бизнес-данные. etcd хранит состояние кластера и leader lock.

## etcd

```text
etcd-1
etcd-2
etcd-3
etcd-4
etcd-5
```

Для 5 etcd-узлов quorum равен 3. Контур переживает отказ двух etcd-узлов.

## Синхронная репликация

Целевой режим:

```yaml
synchronous_mode: true
synchronous_mode_strict: true
synchronous_node_count: 2
postgresql:
  parameters:
    synchronous_commit: "on"
```

Запись доступна, когда есть primary и минимум две synchronous replicas. Если synchronous replicas меньше двух, запись останавливается.

## Proxy-контур

```text
client-a -> PgBouncer -> HAProxy -> PostgreSQL/Patroni
client-b -> PgBouncer -> HAProxy -> PostgreSQL/Patroni
```

HAProxy использует Patroni REST API:

- `/primary` для writer backend;
- `/replica` для reader backend.

PgBouncer дает pooling на стороне клиента. После failover нужно переоткрывать server connections через timeout/lifetime или явный `RECONNECT`.

## Режимы чтения

```text
normal session:
  write -> writer
  read  -> reader

strong session:
  write -> writer
  read  -> writer
```

`strong session` дает простую гарантию read-after-write без LSN-token и ожидания replay на конкретной реплике.
