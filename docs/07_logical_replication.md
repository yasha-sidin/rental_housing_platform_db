# Логическая репликация PostgreSQL

## Назначение

Логическая репликация в проекте используется для выборочной передачи данных из primary в отдельный PostgreSQL-кластер. В отличие от physical replication, она не копирует весь кластер на уровне файлов и WAL-страниц, а передает изменения конкретных таблиц через publication/subscription.

В стенде logical subscriber получает только таблицу:

```text
application.currencies
```

Эта таблица выбрана как стабильный справочник с простым первичным ключом и без сложной доменной связности. Для демонстрации выборочной репликации это лучше, чем брать таблицы бронирований или платежей, где есть много внешних ключей и связанных бизнес-правил.

## Топология

| Роль | Compose service | Порт хоста | Объект PostgreSQL |
| --- | --- | --- | --- |
| Publisher | `rental_housing_platform_db` | `5488` | `rental_currencies_publication` |
| Subscriber | `rental_housing_platform_db_logical_subscriber` | `5491` | `rental_currencies_subscription` |
| Logical slot | primary | - | `rental_currencies_logical_slot` |

Subscriber является отдельным PostgreSQL-кластером со своим `PGDATA` volume. Он не является physical standby и может иметь собственную структуру объектов, пока она совместима с реплицируемыми таблицами.

## Publication на primary

Publication создается в `db/replication/primary_bootstrap.sql`:

```sql
CREATE PUBLICATION rental_currencies_publication
FOR TABLE application.currencies;
```

Publication публикует изменения только одной таблицы `application.currencies`. Это ограничивает область передачи данных и показывает сценарий, где внешней системе нужен не весь кластер, а небольшой согласованный справочник.

Для роли `logical_replicator` выдаются минимально необходимые права:

- `LOGIN`;
- `REPLICATION`;
- `USAGE` на схему `application`;
- `SELECT` на таблицу `application.currencies`.

Пароль роли приходит только из локального `.env` через переменную `LOGICAL_REPLICATION_PASSWORD`. В репозитории нет запасного пароля, а SQL bootstrap дополнительно проверяет, что значение передано и не пустое.

## Schema bootstrap на subscriber

Логическая репликация не переносит DDL. Поэтому совместимая схема создается отдельно:

```text
db/replication/logical_subscriber_schema.sql
```

Скрипт создает:

- схему `application`;
- таблицу `application.currencies` с совместимыми колонками и ограничениями.

На subscriber колонка `id` не объявляется как identity, потому что значения приходят от publisher. Для логической копии справочника важно сохранить идентификаторы источника, а не генерировать новые.

## Subscription на subscriber

Subscription создается в:

```text
db/replication/logical_subscriber_subscription.sql
```

Ключевые параметры:

- `CONNECTION` собирается из переменных окружения контейнера;
- `PUBLICATION rental_currencies_publication`;
- `copy_data = true` - первичная синхронизация копирует уже существующие строки;
- `create_slot = true` - слот создается на publisher автоматически;
- `slot_name = 'rental_currencies_logical_slot'`.

Скрипт проверяет обязательные параметры через psql-переменные. Если не передан host, port, database, user или password, выполнение останавливается.

## Когда полезна logical replication

Логическая репликация подходит для сценариев, где нужна не полная копия кластера, а контролируемый поток изменений:

- выделенный аналитический контур с частью таблиц;
- интеграция справочников во внешние сервисы;
- постепенный перенос данных между PostgreSQL-кластерами;
- репликация между разными версиями PostgreSQL, когда physical replication невозможна;
- построение read model для отдельного bounded context;
- изоляция потребителей данных от основной transactional-схемы.

Для этого проекта пример со справочником валют показывает безопасную границу: внешней системе можно отдавать валюты, не раскрывая пользователей, бронирования, платежи и отзывы.

## Ограничения

Логическая репликация не заменяет physical replication:

- DDL не реплицируется автоматически;
- sequences не синхронизируются как обычные табличные данные;
- subscriber должен иметь совместимую структуру таблиц;
- для корректной репликации `UPDATE` и `DELETE` таблице нужен primary key или подходящий `REPLICA IDENTITY`;
- logical slot также удерживает WAL на primary, если subscriber не успевает читать изменения.

Поэтому logical replication требует отдельного контроля схемы и мониторинга слота `rental_currencies_logical_slot`.

## Запуск

Общий запуск replication-стенда:

```bash
make replication-up
```

Проверить logical publisher и subscriber:

```bash
make replication-logical-status
```

Сохранить базовые артефакты:

```bash
make replication-capture
```

Сохранить демонстрацию вставки:

```bash
make replication-capture-logical-demo
```

## Артефакты проверки

Выводы сохраняются в `artifacts/replication/`:

- `logical_publisher_status.txt` - publication на primary и список публикуемых таблиц;
- `logical_subscriber_config.txt` - примененные настройки subscriber из volume-конфига;
- `logical_subscriber_status.txt` - subscription, receive LSN и количество строк;
- `logical_insert_primary.txt` - вставка проверочной валюты `XLG` на primary;
- `logical_subscriber_after_insert.txt` - проверка, что `XLG` появилась на subscriber.

Ключевые признаки корректного состояния:

- publication содержит только `application.currencies`;
- subscription включена (`subenabled = true`);
- logical slot `rental_currencies_logical_slot` активен на primary;
- `pg_stat_subscription` показывает полученный LSN;
- после вставки на primary строка `XLG` видна на subscriber.
