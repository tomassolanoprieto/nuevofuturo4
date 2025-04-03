-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_supervisor_creation_trigger_v2 ON supervisor_profiles;
DROP FUNCTION IF EXISTS handle_supervisor_creation_v2();

-- Drop existing policies
DROP POLICY IF EXISTS "supervisor_profiles_access_v2" ON supervisor_profiles;
DROP POLICY IF EXISTS "supervisor_employee_access_v2" ON employee_profiles;

-- Drop auth.users foreign key constraint
ALTER TABLE supervisor_profiles 
DROP CONSTRAINT IF EXISTS supervisor_profiles_id_fkey;

-- Create super simple supervisor creation function
CREATE OR REPLACE FUNCTION handle_supervisor_creation_v3()
RETURNS TRIGGER AS $$
BEGIN
  -- Generate new UUID for the supervisor
  NEW.id := gen_random_uuid();

  -- Set default values
  NEW.is_active := COALESCE(NEW.is_active, true);
  NEW.supervisor_type := COALESCE(NEW.supervisor_type, 'center');

  -- Ensure work_centers is an array
  IF NEW.work_centers IS NULL THEN
    NEW.work_centers := ARRAY[]::work_center_enum[];
  END IF;

  -- Ensure delegations is an array
  IF NEW.delegations IS NULL THEN
    NEW.delegations := ARRAY[]::delegation_enum[];
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger with unique name
CREATE TRIGGER handle_supervisor_creation_trigger_v3
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_creation_v3();

-- Create simple policy that allows all operations
CREATE POLICY "allow_all_supervisor_operations_v3"
  ON supervisor_profiles
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);