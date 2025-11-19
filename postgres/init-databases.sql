-- PostgreSQL initialization script for n8n-install
-- This script runs automatically on first database startup
-- It creates all databases required by the various services

-- Create n8n database
SELECT 'Creating database: n8n' AS status;
CREATE DATABASE n8n;
GRANT ALL PRIVILEGES ON DATABASE n8n TO postgres;

-- Create Langfuse database
SELECT 'Creating database: langfuse' AS status;
CREATE DATABASE langfuse;
GRANT ALL PRIVILEGES ON DATABASE langfuse TO postgres;

-- Note: The default 'postgres' database is used by:
-- - Postiz (creates its own schema within postgres)
-- - WAHA (uses postgres database)
-- - LightRAG (uses postgres database when PostgreSQL storage is enabled)

-- You can add more databases here if needed in the future
-- Example:
-- CREATE DATABASE myservice;
-- GRANT ALL PRIVILEGES ON DATABASE myservice TO postgres;
