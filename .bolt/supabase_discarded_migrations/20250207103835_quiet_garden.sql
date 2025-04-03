-- Drop all existing triggers and functions
DO $$ 
BEGIN
  -- Drop triggers
  DROP TRIGGER IF EXISTS handle_employee_import_trigger ON employee_profiles;
  DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;
  DROP TRIGGER IF EXISTS validate_time_entry_trigger ON time_entries;
  DROP TRIGGER IF EXISTS update_daily_hours_trigger ON time_entries;
  DROP TRIGGER IF EXISTS daily_work_hours_update_trigger ON daily_work_hours;
  
  -- Drop functions
  DROP FUNCTION IF EXISTS handle_employee_import();
  DROP FUNCTION IF EXISTS handle_supervisor_auth();
  DROP FUNCTION IF EXISTS validate_time_entry();
  DROP FUNCTION IF EXISTS update_daily_hours();
  DROP FUNCTION IF EXISTS handle_daily_work_hours_updates();
  DROP FUNCTION IF EXISTS validate_work_centers(text[]);
  DROP FUNCTION IF EXISTS send_pin_email(text, text);
END $$;

-- Create single, simplified employee import function
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
  NEW.id := COALESCE(NEW.id, gen_random_uuid());

  -- Create auth user
  INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    raw_app_meta_data,
    role
  )
  VALUES (
    NEW.id,
    NEW.email,
    crypt(NEW.pin, gen_salt('bf')),
    jsonb_build_object(
      'provider', 'email',
      'providers', ARRAY['email'],
      'role', 'employee'
    ),
    'authenticated'
  )
  ON CONFLICT (email) DO UPDATE
  SET encrypted_password = EXCLUDED.encrypted_password,
      raw_app_meta_data = EXCLUDED.raw_app_meta_data;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for employee import
CREATE TRIGGER handle_employee_import_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_import();

-- Create simple policy for employee profiles
CREATE POLICY "employee_access"
  ON employee_profiles
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);