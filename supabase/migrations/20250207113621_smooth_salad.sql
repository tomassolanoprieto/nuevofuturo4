-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_employee_import_trigger ON employee_profiles;
DROP FUNCTION IF EXISTS handle_employee_import();

-- Create simplified employee import function
CREATE OR REPLACE FUNCTION handle_employee_import()
RETURNS TRIGGER AS $$
BEGIN
  -- Basic validation
  IF NEW.email IS NULL THEN
    RAISE EXCEPTION 'Email is required';
  END IF;

  -- Generate 6-digit PIN if not provided
  IF NEW.pin IS NULL THEN
    NEW.pin := LPAD(floor(random() * 1000000)::text, 6, '0');
  END IF;

  -- Validate PIN format
  IF NEW.pin !~ '^\d{6}$' THEN
    RAISE EXCEPTION 'PIN must be exactly 6 digits';
  END IF;

  -- Set default values
  NEW.country := COALESCE(NEW.country, 'España');
  NEW.timezone := COALESCE(NEW.timezone, 'Europe/Madrid');
  NEW.is_active := COALESCE(NEW.is_active, true);
  NEW.work_centers := COALESCE(NEW.work_centers, ARRAY[]::work_center_enum[]);
  NEW.job_positions := COALESCE(NEW.job_positions, ARRAY[]::job_position_enum[]);

  -- Generate new UUID for the employee
  NEW.id := gen_random_uuid();

  -- Create auth user with minimal required fields
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
    RAISE EXCEPTION 'Email % already exists', NEW.email;
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error creating employee: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for employee import
CREATE TRIGGER handle_employee_import_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_import();

-- Create simple policy for employee access
CREATE POLICY "employee_access"
  ON employee_profiles
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);