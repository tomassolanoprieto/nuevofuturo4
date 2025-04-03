-- Drop existing policies first to avoid conflicts
DROP POLICY IF EXISTS "employee_access" ON employee_profiles;
DROP POLICY IF EXISTS "employee_access_policy" ON employee_profiles;
DROP POLICY IF EXISTS "employee_profile_access" ON employee_profiles;
DROP POLICY IF EXISTS "employee_data_access" ON employee_profiles;
DROP POLICY IF EXISTS "employee_data_access_policy" ON employee_profiles;
DROP POLICY IF EXISTS "employee_profiles_policy" ON employee_profiles;
DROP POLICY IF EXISTS "allow_all" ON employee_profiles;
DROP POLICY IF EXISTS "employee_profiles_access_policy_v1" ON employee_profiles;
DROP POLICY IF EXISTS "employee_profiles_access_policy_v2" ON employee_profiles;
DROP POLICY IF EXISTS "employee_profiles_access_policy_v3" ON employee_profiles;

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_employee_import_trigger ON employee_profiles;
DROP FUNCTION IF EXISTS handle_employee_import();

-- Create super simplified employee import function
CREATE OR REPLACE FUNCTION handle_employee_import()
RETURNS TRIGGER AS $$
BEGIN
  -- Generate new UUID for the employee
  NEW.id := gen_random_uuid();

  -- Create auth user with minimal required fields
  INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    role
  )
  VALUES (
    NEW.id,
    NEW.email,
    crypt(COALESCE(NEW.pin, LPAD(floor(random() * 1000000)::text, 6, '0')), gen_salt('bf')),
    'authenticated'
  );

  -- Set default values for employee profile
  NEW.country := COALESCE(NEW.country, 'España');
  NEW.timezone := COALESCE(NEW.timezone, 'Europe/Madrid');
  NEW.is_active := COALESCE(NEW.is_active, true);
  NEW.work_centers := COALESCE(NEW.work_centers, ARRAY[]::work_center_enum[]);
  NEW.job_positions := COALESCE(NEW.job_positions, ARRAY[]::job_position_enum[]);

  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'El email ya existe';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al crear empleado: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger that runs BEFORE INSERT
CREATE TRIGGER handle_employee_import_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_import();

-- Create simple policy with unique name
CREATE POLICY "employee_profiles_access_policy_v4"
  ON employee_profiles
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);