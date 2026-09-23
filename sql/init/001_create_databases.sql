-- ==============================================================================
-- 001_create_databases.sql
-- DBA Setup: Create databases for Lingoria core and platform services
-- Execute with Superuser ('postgres') connected to the default 'postgres' database
-- ==============================================================================

-- 1. Create core application database 'lingoria' if it does not already exist
SELECT 'CREATE DATABASE lingoria ENCODING ''UTF8'' TEMPLATE template1;'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'lingoria')\gexec

-- 2. Create platform metadata database 'airflow' if it does not already exist
SELECT 'CREATE DATABASE airflow ENCODING ''UTF8'' TEMPLATE template1;'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'airflow')\gexec
