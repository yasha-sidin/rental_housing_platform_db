# Индексы PostgreSQL

## Что сделано

- Базовый набор индексов уже был создан в `db/migrations/V009__create_indexes.sql`.
- Новая миграция `db/migrations/V012__create_search_indexes_and_index_comments.sql` добавляет недостающий полнотекстовый индекс и отдельный частичный составной индекс для поиска активных объявлений.
- В этой же миграции добавлены объектные `COMMENT ON INDEX` для явных индексов проекта.
- Запросы для получения планов выполнения лежат в `sql/analytics/indexes_explain.sql`.

## Индексы и сценарии

- Обычный индекс: `application.idx_listings_owner_id`.
- Полнотекстовый индекс: `application.idx_listings_description_fts`.
- Частичный индекс: `application.idx_listings_active_capacity_rooms`.
- Индекс на поле с функцией: `application.idx_addresses_city_id_postal_code`.
- Индекс на несколько полей: `application.idx_bookings_created_by_user_creation_date_desc`.
- Дополнительный частичный индекс из очереди модерации: `application.idx_reviews_unmoderated_creation_date`.

## Как получить EXPLAIN

```bash
make migrate-up
make seed-run
make seed-load N=1000
make dml-run FILE=sql/analytics/indexes_explain.sql
```

Фактический вывод последнего запуска сохранен в `artifacts/explain/indexes_explain.txt`.

## Анализ планов выполнения

### 1. Поиск объявлений владельца

Сценарий использует обычный btree индекс `idx_listings_owner_id`.

Ключевой фрагмент плана:

```text
Index Scan using idx_listings_owner_id on listings listing
  Index Cond: (owner_id = (InitPlan 1).col1)
```

Перед поиском объявлений выполняется `InitPlan`: PostgreSQL находит пользователя по
уникальному индексу `users_username_key`, затем использует найденный `id` как значение
для `owner_id`. После этого таблица `listings` не сканируется целиком: выполняется
точечный `Index Scan` по `idx_listings_owner_id`.

Вывод: индекс подходит для сценария "показать все объявления владельца" и снижает
стоимость доступа к строкам `listings` при фильтрации по `owner_id`.

### 2. Полнотекстовый поиск по описанию объявления

Сценарий использует GIN expression index `idx_listings_description_fts`.

Ключевой фрагмент плана:

```text
Bitmap Heap Scan on listings listing
  Recheck Cond: (to_tsvector(...) @@ '''manhattan'''::tsquery)
  ->  Bitmap Index Scan on idx_listings_description_fts
        Index Cond: (to_tsvector(...) @@ '''manhattan'''::tsquery)
```

`to_tsvector('simple', coalesce(description, ''))` превращает описание объявления в
набор лексем. `plainto_tsquery('simple', 'Manhattan')` превращает пользовательскую
строку поиска в полнотекстовый запрос. Оператор `@@` проверяет, соответствует ли
вектор этому запросу.

GIN индекс устроен как обратный индекс: лексема указывает на строки, где она
встречается. Поэтому PostgreSQL сначала выполняет `Bitmap Index Scan`, находит
кандидатов по слову `manhattan`, затем через `Bitmap Heap Scan` дочитывает строки
таблицы. `Recheck Cond` означает, что точное условие дополнительно проверяется на
строках-кандидатах.

Вывод: полнотекстовый поиск работает через GIN индекс и не требует полного прохода по
текстовым описаниям.

### 3. Поиск активных объявлений по вместимости и комнатам

Сценарий использует частичный составной индекс `idx_listings_active_capacity_rooms`.

Ключевой фрагмент плана:

```text
Index Only Scan using idx_listings_active_capacity_rooms on listings listing
  Index Cond: ((capacity = 2) AND (number_of_rooms = 1))
  Heap Fetches: 0
```

Индекс создан только для строк `WHERE status = 'active'`, поэтому в самом индексе
нет скрытых и заблокированных объявлений. Запрос повторяет это условие и дополнительно
фильтрует по `capacity` и `number_of_rooms`.

`Index Only Scan` означает, что PostgreSQL смог получить результат из индекса без
чтения строк таблицы. В плане это подтверждает `Heap Fetches: 0`.

Вывод: частичный индекс уменьшает размер индекса и ускоряет типовой пользовательский
поиск активного жилья по параметрам размещения.

### 4. Поиск адреса по городу и нормализованному postal_code

Сценарий использует составной expression index `idx_addresses_city_id_postal_code`.

Ключевой фрагмент плана:

```text
Index Scan using idx_addresses_city_id_postal_code on addresses address
  Index Cond: ((city_id = 20) AND (lower((postal_code)::text) = '010500'::text))
```

Индекс построен по двум выражениям: `city_id` и `lower(postal_code)`. Поэтому запрос
содержит оба условия: сначала ограничивает адреса конкретным городом, затем ищет
нормализованный почтовый индекс.

Важно, что выражение в запросе совпадает с выражением в индексе: `lower(postal_code)`.
Если искать просто по `postal_code` без `lower(...)`, этот expression index для второй
части условия не подойдет.

Вывод: индекс закрывает сценарий регистронезависимого поиска адреса внутри города и
показывает использование индекса на поле с функцией.

### 5. История бронирований пользователя

Сценарий использует составной индекс `idx_bookings_created_by_user_creation_date_desc`.

Ключевой фрагмент плана:

```text
Bitmap Heap Scan on bookings booking
  Recheck Cond: (created_by_user_id = (InitPlan 1).col1)
  ->  Bitmap Index Scan on idx_bookings_created_by_user_creation_date_desc
        Index Cond: (created_by_user_id = (InitPlan 1).col1)
```

Сначала через `InitPlan` находится пользователь по `users_username_key`, затем его `id`
используется для фильтрации `bookings.created_by_user_id`. Индекс начинается с
`created_by_user_id`, поэтому PostgreSQL может быстро найти бронирования конкретного
гостя.

В этом запуске PostgreSQL выбрал `Bitmap Index Scan` и отдельную сортировку по
`creation_date DESC`. Это допустимый план: найдено несколько десятков строк, и
планировщик посчитал bitmap-доступ плюс сортировку дешевле прямого ordered
`Index Scan`.

Вывод: составной индекс используется для фильтрации по пользователю. На другом объеме
данных или другой селективности PostgreSQL может выбрать прямой `Index Scan` по этому
же индексу и использовать порядок `creation_date DESC` из индекса.

## Нюансы и проблемы

- На маленьких таблицах PostgreSQL может выбрать `Seq Scan`, даже если подходящий индекс есть. Это нормальное решение планировщика: прочитать маленькую таблицу целиком дешевле, чем идти в индекс.
- Для показательных планов лучше использовать нагрузочные данные через `make seed-load N=1000`.
- Индексы, созданные после `V011`, нужно явно помещать в `TABLESPACE rental_index_ts`, иначе они останутся в tablespace по умолчанию.
- Для expression index полнотекстового поиска выражение в запросе должно совпадать с выражением в индексе: `to_tsvector('simple', coalesce(description, ''))`.
- Старые миграции не изменялись, чтобы не ломать уже примененную историю схемы.
