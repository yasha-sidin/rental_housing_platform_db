# Проектирование схемы базы данных

## Миграции

Цепочка миграций компактная и читаемая:

```text
V001__database_baseline.sql
V002__reference_catalogs.sql
V003__users_listings_photos.sql
V004__pricing_availability.sql
V005__bookings_payments_reviews.sql
V006__indexes_comments_grants.sql
```

## Принципы

- В первой миграции создается прикладная схема `application`.
- Все таблицы, ограничения, индексы, комментарии и права доступа создаются внутри схемы `application`.
- Индексы и комментарии сгруппированы в отдельной миграции.
- Rollback-файлы парные и соответствуют up-миграциям.

## Данные

Seed-данные разделены по смыслу:

```text
001_reference.sql
002_demo_users_listings.sql
003_booking_scenarios.sql
004_pitr_scenario.sql
999_cleanup.sql
```

Массовая генерация данных вынесена в команду `bin/rentalctl seedgen` (`bin/rentalctl.exe seedgen` на Windows). Генератор написан на Go и создает SQL на лету, чтобы в репозитории не хранить большой нечитаемый seed-скрипт.

## Проверки

SQL-проверки находятся в `db/tests/`. Они фиксируют не весь набор тестов, а ключевые инварианты, которые удобно показать на защите.
