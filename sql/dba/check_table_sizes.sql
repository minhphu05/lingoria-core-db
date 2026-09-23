-- ==============================================================================
-- check_table_sizes.sql
-- DBA Diagnostic: List all tables and indexes sorted by total disk space
-- Execute on database 'lingoria'
-- ==============================================================================

SELECT
    schemaname AS schema_name,
    relname AS table_name,
    n_live_tup AS estimated_rows,
    pg_size_pretty(pg_relation_size(relid)) AS data_size,
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) AS index_size,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
