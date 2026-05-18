# ADR 001: Patroni для PostgreSQL HA

## Решение

Использовать Patroni для управления PostgreSQL-кластером, выбора primary и automatic failover.

## Обоснование

Patroni хорошо ложится на учебную цель проекта: он явно показывает роль DCS, leader lock, promotion и health-check endpoints. Это проще объяснять на защите, чем скрытый managed service.

## Последствия

- Нужен отдельный DCS-контур.
- Нужно документировать сценарии потери quorum.
- HAProxy может маршрутизировать трафик по Patroni REST API.
