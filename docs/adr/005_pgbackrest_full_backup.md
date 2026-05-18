# ADR 005: pgBackRest и full backup

## Решение

Использовать pgBackRest для full backup, WAL archive и PITR.

## Обоснование

pgBackRest хорошо документирован, поддерживает S3-compatible repositories и является распространенным выбором в PostgreSQL HA-проектах и Kubernetes operators.

## Последствия

- Для production нужен отдельный restore drill.
- Backup workers должны иметь lock-механику, чтобы не запускать несколько backup одновременно.
