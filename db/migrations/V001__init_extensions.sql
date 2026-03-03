-- V001: инициализация расширений PostgreSQL.

-- Использую pg_stat_statements для сбора статистики по SQL-запросам:
-- время, количество вызовов, средние/максимальные значения и т.д.
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
