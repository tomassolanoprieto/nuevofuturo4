-- Create function to validate and convert work centers
CREATE OR REPLACE FUNCTION validate_work_centers(centers text[])
RETURNS work_center_enum[] AS $$
DECLARE
  valid_centers work_center_enum[];
  center text;
BEGIN
  valid_centers := ARRAY[]::work_center_enum[];
  
  FOREACH center IN ARRAY centers
  LOOP
    BEGIN
      -- Try to cast the center to work_center_enum
      valid_centers := array_append(valid_centers, center::work_center_enum);
    EXCEPTION
      WHEN invalid_text_representation THEN
        -- Skip invalid centers
        CONTINUE;
    END;
  END LOOP;
  
  RETURN valid_centers;
END;
$$ LANGUAGE plpgsql;

-- Create function to handle employee import
CREATE OR REPLACE FUNCTION handle_employee_import()
RETURNS TRIGGER AS $$
BEGIN
  -- Basic validation
  IF NEW.email IS NULL THEN
    RAISE EXCEPTION 'Email is required';
  END IF;

  IF NEW.pin IS NULL THEN
    RAISE EXCEPTION 'PIN is required';
  END IF;

  IF NEW.pin !~ '^\d{6}$' THEN
    RAISE EXCEPTION 'PIN must be exactly 6 digits';
  END IF;

  -- Validate work centers
  IF NEW.work_centers IS NOT NULL THEN
    NEW.work_centers := validate_work_centers(NEW.work_centers::text[]);
  END IF;

  -- Generate new UUID for the employee
  NEW.id := gen_random_uuid();

  -- Create auth user
  INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    role
  )
  VALUES (
    NEW.id,
    NEW.email,
    crypt(NEW.pin, gen_salt('bf')),
    NOW(),
    jsonb_build_object(
      'provider', 'email',
      'providers', ARRAY['email'],
      'role', 'employee'
    ),
    'authenticated'
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS handle_employee_import_trigger ON employee_profiles;

-- Create trigger for employee import
CREATE TRIGGER handle_employee_import_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_import();

-- Create policy for employee import
CREATE POLICY "Allow employee import"
  ON employee_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM company_profiles
      WHERE company_profiles.id = auth.uid()
    )
  );