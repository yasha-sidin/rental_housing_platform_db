# 05-sync-rpo-zero

Цель: показать сохранность подтвержденной транзакции при failover и остановку записи при нехватке двух synchronous replicas.

Ожидаемые артефакты:

- запись до отказа primary;
- чтение после failover;
- ошибка записи при недостатке synchronous replicas.
