# Выгрузка витрины активных объявлений

## Что выполнялось

Сценарий экспортирует аналитическую витрину по активным объявлениям: владелец, страна, город, тип объекта, описание, вместимость, базовая цена и валюта.

SQL-запрос: `request.sql`.

## Полученный результат

Артефакт выполнения находится в `artifacts/active_listings_report.csv`. CSV-файл содержит заголовок и строки активных объявлений, отсортированные по стране, городу и идентификатору объявления.

[CSV-артефакт выгрузки активных объявлений](artifacts/active_listings_report.csv)

Фрагмент артефакта:

```csv
listing_id,owner_username,country_name,city_name,object_type_name,description,capacity,number_of_rooms,base_price_in_minor,currency_code
300029,load_owner_19,Brazil,Rio de Janeiro,studio,Load listing #19,2,4,10019,RUB
300049,load_owner_39,Brazil,Rio de Janeiro,cabin,Load listing #39,4,4,10039,RUB
300069,load_owner_59,Brazil,Rio de Janeiro,studio,Load listing #59,6,4,10059,RUB
300089,load_owner_79,Brazil,Rio de Janeiro,cabin,Load listing #79,2,4,10079,RUB
```

## Что доказывает сценарий

Витрина подтверждает, что нормализованные справочники не мешают аналитическому чтению. Через соединение таблиц `listings`, `users`, `object_types`, `addresses`, `cities`, `countries`, `base_prices` и `currencies` формируется плоский отчет, пригодный для внешнего анализа.
