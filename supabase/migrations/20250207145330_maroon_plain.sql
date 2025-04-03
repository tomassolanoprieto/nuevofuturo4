-- Drop existing policies
DROP POLICY IF EXISTS "employee_profiles_access_policy_v4" ON employee_profiles;

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_employee_import_trigger ON employee_profiles;
DROP FUNCTION IF EXISTS handle_employee_import();

-- Drop auth.users foreign key constraint if exists
ALTER TABLE employee_profiles 
DROP CONSTRAINT IF EXISTS employee_profiles_id_fkey;

-- Drop company_id foreign key constraint if exists
ALTER TABLE employee_profiles
DROP CONSTRAINT IF EXISTS employee_profiles_company_id_fkey;

-- Create simple employee creation function without auth
CREATE OR REPLACE FUNCTION handle_employee_creation()
RETURNS TRIGGER AS $$
BEGIN
  -- Generate new UUID for the employee
  NEW.id := gen_random_uuid();

  -- Set default values
  NEW.country := COALESCE(NEW.country, 'España');
  NEW.timezone := COALESCE(NEW.timezone, 'Europe/Madrid');
  NEW.is_active := COALESCE(NEW.is_active, true);
  NEW.work_centers := COALESCE(NEW.work_centers, ARRAY[]::work_center_enum[]);
  NEW.job_positions := COALESCE(NEW.job_positions, ARRAY[]::job_position_enum[]);
  NEW.pin := COALESCE(NEW.pin, LPAD(floor(random() * 1000000)::text, 6, '0'));

  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'El email ya existe';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al crear empleado: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for employee creation
CREATE TRIGGER handle_employee_creation_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_creation();

-- Create simple policy that allows all operations
CREATE POLICY "employee_profiles_simple_access"
  ON employee_profiles
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_email ON employee_profiles(email);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_company_id ON employee_profiles(company_id);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_is_active ON employee_profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers ON employee_profiles USING gin(work_centers);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_job_positions ON employee_profiles USING gin(job_positions);