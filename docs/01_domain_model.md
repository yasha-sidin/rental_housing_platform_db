# Domain Model

Предметная область - краткосрочная аренда жилья.

## Основные сущности

- `users` - пользователи платформы.
- `roles`, `permissions`, `user_roles`, `role_permissions` - RBAC-модель.
- `countries`, `cities`, `addresses` - география и адреса.
- `object_types` - типы объектов жилья.
- `listings` - объявления.
- `photos`, `listing_photos` - фотографии объявлений.
- `currencies` - валюты.
- `base_prices` - базовые цены.
- `listing_availability_days` - календарь доступности.
- `price_history` - история изменения цен.
- `bookings`, `booking_days` - бронирования и выбранные даты.
- `payments` - платежные сессии.
- `reviews` - отзывы.

## Ключевые инварианты

- Объявления не удаляются физически, а переводятся в нужный статус.
- Дни доступности не удаляются физически.
- Один день не может быть связан с двумя активными бронированиями.
- Платежная сессия не создается после истечения окна оплаты бронирования.
- Отзыв можно создать только по завершенному бронированию.
- День и бронирование должны относиться к одному listing.

## Статусы

`listing_publication_status`:

```text
active, hidden, blocked
```

`availability_status`:

```text
available, held, booked, blocked
```

`booking_status`:

```text
created, payment_pending, confirmed, expired, cancelled, completed
```

`payment_status`:

```text
initiated, paid, failed, cancelled, expired, partially_refunded, refunded
```
