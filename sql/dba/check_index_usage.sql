-- ==============================================================================
-- check_index_usage.sql
-- DBA Diagnostic: Evaluate index utilization and detect sequential scan bottlenecks
-- Execute on database 'lingoria'
-- ==============================================================================

SELECT
    schemaname,
    relname AS table_name,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    CASE
        WHEN (seq_scan + idx_scan) = 0 THEN 0
        ELSE ROUND((idx_scan::numeric / (seq_scan + idx_scan) * 100), 2)
    END AS index_usage_percent
FROM pg_stat_user_tables
ORDER BY seq_scan DESC;
