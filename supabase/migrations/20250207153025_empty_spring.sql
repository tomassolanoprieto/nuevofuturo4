-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_employee_creation_trigger ON employee_profiles;
DROP FUNCTION IF EXISTS handle_employee_creation();

-- Drop existing policy if exists
DROP POLICY IF EXISTS "employee_profiles_access" ON employee_profiles;

-- Create improved employee import function
CREATE OR REPLACE FUNCTION handle_employee_creation()
RETURNS TRIGGER AS $$
BEGIN
  -- Generate new UUID for the employee
  NEW.id := gen_random_uuid();

  -- Set default values
  NEW.country := COALESCE(NEW.country, 'España');
  NEW.timezone := COALESCE(NEW.timezone, 'Europe/Madrid');
  NEW.is_active := COALESCE(NEW.is_active, true);
  NEW.pin := COALESCE(NEW.pin, LPAD(floor(random() * 1000000)::text, 6, '0'));

  -- Ensure work_centers is an array
  IF NEW.work_centers IS NULL THEN
    NEW.work_centers := ARRAY[]::work_center_enum[];
  END IF;

  -- Convert single work center to array if needed
  IF array_length(NEW.work_centers, 1) IS NULL AND NEW.work_centers[1] IS NOT NULL THEN
    NEW.work_centers := ARRAY[NEW.work_centers[1]]::work_center_enum[];
  END IF;

  -- Ensure job_positions is an array
  IF NEW.job_positions IS NULL THEN
    NEW.job_positions := ARRAY[]::job_position_enum[];
  END IF;

  -- Convert single job position to array if needed
  IF array_length(NEW.job_positions, 1) IS NULL AND NEW.job_positions[1] IS NOT NULL THEN
    NEW.job_positions := ARRAY[NEW.job_positions[1]]::job_position_enum[];
  END IF;

  -- Create auth user
  INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    role
  )
  VALUES (
    NEW.id,
    NEW.email,
    crypt(NEW.pin, gen_salt('bf')),
    NOW(),
    'authenticated'
  );

  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'El email ya existe';
  WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'Centro de trabajo o puesto no válido';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al crear empleado: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for employee creation
CREATE TRIGGER handle_employee_creation_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_creation();

-- Create policy with a unique name
CREATE POLICY "employee_profiles_access_v5"
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