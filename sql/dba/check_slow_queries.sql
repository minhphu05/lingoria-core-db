-- ==============================================================================
-- check_slow_queries.sql
-- DBA Diagnostic: List currently running queries taking longer than 2 seconds
-- Execute on database 'lingoria'
-- ==============================================================================

SELECT
    pid,
    usename,
    client_addr,
    now() - query_start AS duration,
    state,
    query
FROM pg_stat_activity
WHERE state != 'idle'
  AND (now() - query_start) > interval '2 seconds'
ORDER BY duration DESC;
