-- Drop supervisor-related policies
DROP POLICY IF EXISTS "Supervisors can view their own profile" ON supervisor_profiles;
DROP POLICY IF EXISTS "Companies can manage their supervisors" ON supervisor_profiles;
DROP POLICY IF EXISTS "Supervisors can view employee data" ON employee_profiles;

-- Drop supervisor-related triggers and functions
DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;
DROP FUNCTION IF EXISTS handle_supervisor_auth();

-- Drop supervisor_profiles table
DROP TABLE IF EXISTS supervisor_profiles;