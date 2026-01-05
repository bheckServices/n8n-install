-- PostgreSQL remote access user setup
-- This script creates a dedicated user for remote connections (DataGrip, n8n, etc.)
-- Run this script AFTER initial setup if you need remote database access

-- Note: Replace 'your_secure_password_here' with a strong password
-- You can generate one using: openssl rand -base64 32

DO $$
BEGIN
    -- Create remote access user if it doesn't exist
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'remote_user') THEN
        CREATE USER remote_user WITH PASSWORD 'CHANGE_THIS_PASSWORD';
        RAISE NOTICE 'Created user: remote_user';
    ELSE
        RAISE NOTICE 'User remote_user already exists';
    END IF;
END
$$;

-- Grant connection privileges to all databases
GRANT CONNECT ON DATABASE postgres TO remote_user;
GRANT CONNECT ON DATABASE n8n TO remote_user;
GRANT CONNECT ON DATABASE langfuse TO remote_user;

-- Grant schema usage on public schema for all databases
-- Note: You need to connect to each database to grant schema-level privileges
-- This script grants on the default 'postgres' database
GRANT USAGE ON SCHEMA public TO remote_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO remote_user;
GRANT SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO remote_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO remote_user;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO remote_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, UPDATE ON SEQUENCES TO remote_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO remote_user;

-- For n8n database (connect and grant)
\c n8n
GRANT USAGE ON SCHEMA public TO remote_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO remote_user;
GRANT SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO remote_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO remote_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO remote_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, UPDATE ON SEQUENCES TO remote_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO remote_user;

-- For langfuse database (connect and grant)
\c langfuse
GRANT USAGE ON SCHEMA public TO remote_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO remote_user;
GRANT SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO remote_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO remote_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO remote_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, UPDATE ON SEQUENCES TO remote_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO remote_user;

-- Switch back to postgres database
\c postgres

SELECT 'Remote user setup complete!' AS status;
SELECT 'User: remote_user' AS info;
SELECT 'Databases granted: postgres, n8n, langfuse' AS info;
SELECT 'IMPORTANT: Change the password in this file before running!' AS warning;
