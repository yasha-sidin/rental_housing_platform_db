# ADR 004: Client-local PgBouncer + HAProxy

## Решение

Для демонстрации использовать отдельный PgBouncer для каждого клиента и общий HAProxy routing pattern.

## Обоснование

Отказ proxy одного клиента не должен ломать доступ другого клиента к кластеру. Идея похожа на client-local ProxySQL в MySQL-стенде.

## Последствия

- Нужно отдельно описать reconnect PgBouncer после failover.
- Клиент должен явно выбирать normal/strong режим чтения.
