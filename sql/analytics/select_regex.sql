-- select_regex.sql
-- Домашнее задание: DML в PostgreSQL.
--
-- Условие:
-- Написать запрос по своей базе с регулярным выражением и добавить пояснение,
-- что именно требуется найти.
--
-- Выбранный сценарий:
-- Найти объявления, созданные seed-скриптами, у которых описание соответствует
-- формату `Seed listing <локация>`. Регулярное выражение удобно здесь потому,
-- что оно позволяет отделить служебный префикс от смысловой части описания и
-- извлечь название локации из текстового поля.
--
-- Реализация:

SET search_path = application, public;

SELECT
    matched_listing.id,
    matched_listing.description,
    matched_listing.extracted_location,
    matched_listing.status,
    matched_listing.capacity,
    matched_listing.number_of_rooms
FROM (
         SELECT
             id,
             description,
             substring(description FROM '^Seed listing (.+)$') AS extracted_location,
             status,
             capacity,
             number_of_rooms
         FROM listings
     ) AS matched_listing
WHERE matched_listing.extracted_location IS NOT NULL
ORDER BY matched_listing.extracted_location;
