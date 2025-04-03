-- Enable pg_net extension
CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA extensions TO postgres, anon, authenticated, service_role;

-- Allow authenticated users to use pg_net functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA net TO authenticated;