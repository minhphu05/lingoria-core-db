-- ==============================================================================
-- 003_extensions.sql
-- DBA Setup: Enable required extensions on the 'lingoria' database
-- Connect to database 'lingoria' as Superuser ('postgres')
-- ==============================================================================

\connect lingoria;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "vector";

-- Verify installed extensions
SELECT extname, extversion FROM pg_extension WHERE extname IN ('uuid-ossp', 'pgcrypto', 'citext', 'pg_trgm', 'vector');
