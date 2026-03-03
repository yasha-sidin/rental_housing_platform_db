# Доменная модель

Документ описывает структуру данных платформы краткосрочной аренды на уровне сущностей, таблиц и связей.

## 1. Пользователи и RBAC

### 1.1 Пользователи
- Таблица: `users`
- Назначение: учетные записи гостей, владельцев и администраторов.
- Ключевые поля:
  - `id` — PK
  - `username`, `phone_number`, `email` — уникальные контактные идентификаторы
  - `status` — `user_status` (`active`, `blocked`, `pending`, `deleted`)
  - `register_date` — дата регистрации

### 1.2 Роли
- Таблица: `roles`
- Назначение: системные роли (`guest`, `owner`, `admin`) и потенциально новые роли.

### 1.3 Разрешения
- Таблица: `permissions`
- Назначение: атомарные права в формате `resource.action`.

### 1.4 Связи RBAC
- Таблица: `user_roles`
  - Связь `users` ↔ `roles` (many-to-many)
- Таблица: `role_permissions`
  - Связь `roles` ↔ `permissions` (many-to-many)

## 2. Справочники и адреса

### 2.1 Типы объектов
- Таблица: `object_types`
- Назначение: словарь типов жилья (квартира, дом, студия и т.д.).

### 2.2 География
- Таблица: `countries`
  - ISO alpha-2 код страны (`code`)
- Таблица: `cities`
  - Город в рамках страны
- Таблица: `addresses`
  - Нормализованный адрес: `city_id`, `street_line1`, `street_line2`, `region`, `postal_code`, `link`

Связи:
- `countries` 1:N `cities`
- `cities` 1:N `addresses`

### 2.3 Валюты
- Таблица: `currencies`
- Назначение: ISO-валюты, признаки активности, `minor_unit`.

## 3. Объявления и фото

### 3.1 Объявления
- Таблица: `listings`
- Назначение: карточка объекта размещения.
- Ключевые поля:
  - `owner_id` → `users`
  - `object_type_id` → `object_types`
  - `address_id` → `addresses`
  - `capacity`, `number_of_rooms`, `description`
  - `status` — `listing_publication_status` (`active`, `hidden`, `blocked`)
  - `creation_date`, `last_update_date`

Связи:
- `users` (владелец) 1:N `listings`
- `addresses` 1:N `listings`

### 3.2 Фото
- Таблица: `photos`
  - Хранит метаданные фото и ссылку (`link`)
- Таблица: `listing_photos`
  - Связь `listings` ↔ `photos`
  - `slot` в диапазоне `1..20` (позиция фото в объявлении)

Ключевая бизнес-модель:
- одно фото не может принадлежать двум объявлениям одновременно;
- у объявления может быть максимум 20 фото.

## 4. Цены и доступность

### 4.1 Базовая цена
- Таблица: `base_prices`
- Назначение: текущая базовая цена за ночь для объявления.
- Ограничение модели: одна запись базовой цены на один `listing`.

### 4.2 Доступность по дням
- Таблица: `listing_availability_days`
- Назначение: календарь доступности по принципу «1 день = 1 запись».
- Ключевые поля:
  - `listing_id`
  - `available_date`
  - `status` — `availability_status` (`available`, `held`, `booked`, `blocked`)
  - `override_currency_id`, `override_in_minor` — дневной override цены

Ограничение модели:
- уникальность пары (`listing_id`, `available_date`).

### 4.3 История цен
- Таблица: `price_history`
- Назначение: аудит изменений базовой и дневной цены.
- Ключевые поля:
  - `source` — `price_change_source` (`base_price`, `day_override`)
  - старые/новые значения цены и валюты
  - `changed_at`, `changed_by_user_id`, `reason`

Связь цен:
- `base_prices` и `listing_availability_days` выступают источниками текущей цены;
- `price_history` хранит историю изменений.

## 5. Бронирования

### 5.1 Бронирование
- Таблица: `bookings`
- Назначение: заголовок брони.
- Ключевые поля:
  - `listing_id` — объект бронирования
  - `created_by_user_id` — гость
  - `guests_count`
  - `total_amount_currency_id`, `total_amount_in_minor`
  - `status` — `booking_status` (`created`, `payment_pending`, `confirmed`, `expired`, `cancelled`, `completed`)
  - `booking_expires_at` — крайний срок старта оплаты
  - `cancelled_by_user_id`, `cancellation_reason`

### 5.2 Дни бронирования
- Таблица: `booking_days`
- Назначение: выбранные дни проживания, привязанные к брони.
- Роль в модели:
  - поддержка произвольного (в том числе разрывного) набора дат;
  - гарантия, что все дни брони принадлежат одному и тому же `listing`.

Связи:
- `bookings` 1:N `booking_days`
- `listing_availability_days` 1:N `booking_days` (с учетом бизнес-ограничений по активным статусам)

## 6. Платежи

### 6.1 Платеж
- Таблица: `payments`
- Назначение: платежная сессия/операция по бронированию.
- Ключевые поля:
  - `booking_id` (уникально: одна платежная сессия на бронь)
  - `currency_id`, `amount_in_minor`
  - `refunded_amount_in_minor`
  - `status` — `payment_status` (`initiated`, `paid`, `failed`, `cancelled`, `expired`, `partially_refunded`, `refunded`)
  - `provider_payment_session_id`, `provider_payment_session_expires_at`
  - `initiated_date`, `last_update_date`

## 7. Отзывы

### 7.1 Отзыв
- Таблица: `reviews`
- Назначение: отзыв и оценка по конкретному бронированию.
- Ключевые поля:
  - `booking_id` (уникально: один отзыв на бронь)
  - `mark` (1..5)
  - `body`
  - `moderated`, `moderation_date`

Связь:
- `bookings` 1:1 `reviews` (логически, за счет `UNIQUE(booking_id)`)

## 8. Основные статусные модели

- `user_status`: жизненный цикл учетной записи пользователя.
- `listing_publication_status`: публичный статус объявления.
- `availability_status`: состояние доступности конкретного дня.
- `booking_status`: жизненный цикл бронирования.
- `payment_status`: жизненный цикл платежа и возвратов.
- `price_change_source`: источник изменения цены для истории.
- `photo_extension`: допустимые типы изображений.

## 9. Общая картина связей

- Пользователь может иметь несколько ролей и быть владельцем нескольких объявлений.
- Объявление связано с типом объекта и адресом.
- Доступность и цена моделируются по дням, что позволяет гибко задавать набор дат и override-стоимости.
- Бронирование хранится отдельно от выбранных дней, а дни соединяются через `booking_days`.
- Платеж связан с бронированием (1:1 в текущей модели).
- Отзыв связан с бронированием (1:1).
