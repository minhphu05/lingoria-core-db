-- ==============================================================================
-- 002_create_roles.sql
-- DBA Setup: Create application roles/users and grant base privileges
-- Execute with Superuser ('postgres')
-- ==============================================================================

-- 1. Create Application Role for Lingoria Core Services
DO
$do$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'lingoria') THEN
      CREATE ROLE lingoria WITH LOGIN PASSWORD 'lingoria_local_change_me';
   END IF;
END
$do$;

-- Grant permissions on database 'lingoria'
GRANT ALL PRIVILEGES ON DATABASE lingoria TO lingoria;
ALTER DATABASE lingoria OWNER TO lingoria;

-- 2. Create Role for Apache Airflow Metadata
DO
$do$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'airflow') THEN
      CREATE ROLE airflow WITH LOGIN PASSWORD 'airflow_service_change_me';
   END IF;
END
$do$;

-- Grant permissions on database 'airflow'
GRANT ALL PRIVILEGES ON DATABASE airflow TO airflow;
ALTER DATABASE airflow OWNER TO airflow;
