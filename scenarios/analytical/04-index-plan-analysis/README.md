# Анализ планов выполнения и индексов

## Что выполнялось

Сценарий выполняет `EXPLAIN (ANALYZE, BUFFERS)` для запросов, соответствующих ключевым индексам проекта:

- `idx_listings_owner_id` - объявления конкретного владельца;
- `idx_listings_description_fts` - полнотекстовый поиск по описанию;
- `idx_listings_active_capacity_rooms` - поиск активных объявлений по вместимости и числу комнат;
- `idx_addresses_city_id_postal_code` - поиск адреса по городу и нормализованному почтовому индексу;
- `idx_bookings_created_by_user_creation_date_desc` - история бронирований пользователя.

SQL-запрос: `indexes_explain.sql`.

## Полученный результат

Полный вывод сохранен в `artifacts/indexes_explain.txt`. В нем зафиксированы фактическое время выполнения, типы сканирования, использованные индексы и обращения к буферам.

[TXT-артефакт анализа планов выполнения](artifacts/indexes_explain.txt)

Фрагмент артефакта:

```text
Index Scan using users_username_key on users "user"
Index Scan using idx_listings_owner_id on listings listing
Bitmap Index Scan on idx_listings_description_fts
Index Only Scan using idx_listings_active_capacity_rooms on listings listing
Index Scan using idx_addresses_city_id_postal_code on addresses address
```

## Что доказывает сценарий

Планы выполнения подтверждают, что индексы создаются не формально, а под конкретные сценарии доступа. На небольших таблицах PostgreSQL может выбрать последовательное чтение, но на нагрузочных данных видны `Index Scan`, `Bitmap Index Scan` и `Index Only Scan` там, где селективность запроса делает индекс полезным.
