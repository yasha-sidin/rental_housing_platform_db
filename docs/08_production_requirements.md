# Production Requirements

Docker-стенд демонстрационный. Для production нужны дополнительные требования.

## Размещение

- Узлы должны быть разнесены по failure domains.
- etcd должен иметь независимые диски и сеть.
- PostgreSQL-узлы не должны находиться на одном физическом хосте.

## Сеть

- TLS между клиентами, proxy и PostgreSQL.
- Ограничение доступа к Patroni REST API.
- Отдельные security groups/firewall rules для etcd, PostgreSQL, proxy, backup и monitoring.

## Backup repository

- Надежное S3-compatible object storage.
- Versioning.
- Object Lock/WORM для защиты от удаления и ransomware-сценариев.
- Encryption at rest.
- Retention policy.
- Мониторинг WAL archive lag.

## Secrets

- Пароли и S3 credentials не хранятся в git.
- Secrets выдаются через secret manager или защищенный CI/CD контур.
- Доступ backup workers к S3 ограничен только нужным bucket/prefix.

## RPO/RTO

Production должен явно зафиксировать:

- RPO для отказа primary;
- RPO для disaster recovery через backup/PITR;
- RTO failover;
- RTO restore;
- RTO PITR.

## Monitoring

- alert на потерю primary;
- alert на потерю synchronous replicas;
- alert на etcd quorum risk;
- alert на WAL archive failure;
- alert на отсутствие свежего backup;
- регулярный restore drill.

## Операционные процедуры

- runbook failover;
- runbook потери quorum;
- runbook восстановления из backup;
- runbook PITR;
- runbook ротации секретов;
- runbook обновления PostgreSQL/Patroni/etcd.
