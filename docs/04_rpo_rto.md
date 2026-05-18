# RPO и RTO

## RPO

`RPO = 0` означает, что подтвержденные клиенту транзакции не теряются при отказе primary.

В проекте это обеспечивается комбинацией:

- `synchronous_commit = on`;
- `synchronous_mode = true`;
- `synchronous_mode_strict = true`;
- `synchronous_node_count = 2`;
- минимум две synchronous replicas для подтверждения записи.

Если доступна только одна synchronous replica или ни одной, запись должна остановиться. Это защитное поведение, а не деградация гарантии.

## Ограничения RPO = 0

`RPO = 0` не защищает от логических ошибок. Ошибочный `DELETE`, `UPDATE`, `DROP` или плохая миграция будут реплицированы на все узлы.

Для логических ошибок нужен PITR.

## RTO

`RTO` - время восстановления.

В проекте измеряются три типа RTO:

- automatic failover;
- restore из full backup;
- PITR на recovery-node.

## Как измерять automatic failover

```text
1. Зафиксировать время остановки primary.
2. Дождаться, пока HAProxy writer endpoint начнет вести на новый primary.
3. Проверить `select pg_is_in_recovery()` = false.
4. Выполнить тестовую запись.
5. RTO = время от остановки primary до первой успешной записи.
```

## Как измерять restore

```text
1. Зафиксировать время старта restore.
2. Восстановить recovery-node из full backup.
3. Запустить PostgreSQL.
4. Выполнить проверочный SELECT.
5. RTO = время от старта restore до успешной проверки данных.
```

## Как измерять PITR

```text
1. Создать restore point или зафиксировать timestamp до логической ошибки.
2. Выполнить логическую ошибку.
3. Восстановить recovery-node из full backup и WAL archive до нужного момента.
4. Проверить, что данные восстановлены до состояния перед ошибкой.
```
