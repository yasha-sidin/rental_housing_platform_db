-- insert_returning.sql
-- Домашнее задание: DML в PostgreSQL.
--
-- Условие:
-- Написать запрос на добавление данных с выводом информации о добавленных строках.
--
-- Выбранный сценарий:
-- Добавить новое фото в справочник фотографий и сразу вывести данные созданной строки.
-- Это хорошо демонстрирует INSERT INTO ... RETURNING: приложение может получить
-- id, ссылку, расширение и дату создания без отдельного SELECT после вставки.
-- Ссылка формируется динамически, чтобы скрипт можно было безопасно запускать повторно.
--
-- Реализация:

SET search_path = application, public;

BEGIN;

INSERT INTO photos
(extension, link, creation_date)
VALUES
(
    'jpeg',
    'https://homework.example/photos/insert-returning-' ||
        to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') ||
        '.jpg',
    now()
)
RETURNING id, extension, link, creation_date;

ROLLBACK;
