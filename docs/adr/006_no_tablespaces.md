# ADR 006: Без tablespaces

## Решение

Не использовать PostgreSQL tablespaces в целевой архитектуре проекта.

## Обоснование

Tablespaces усложняют объяснение HA-репликации и Docker-стенда. Для темы отказоустойчивого кластера важнее synchronous replication, failover, backup и PITR.

## Последствия

- Миграции становятся короче.
- Исчезает cluster-level bootstrap до application migrations.
- Документация фокусируется на HA, а не на моделировании физических дисков.
