-- Drop existing policies
DROP POLICY IF EXISTS "employee_profile_access" ON employee_profiles;
DROP POLICY IF EXISTS "employee_profiles_policy" ON employee_profiles;
DROP POLICY IF EXISTS "allow_all" ON employee_profiles;

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_employee_import_trigger ON employee_profiles;
DROP FUNCTION IF EXISTS handle_employee_import();

-- Create improved employee import function
CREATE OR REPLACE FUNCTION handle_employee_import()
RETURNS TRIGGER AS $$
DECLARE
  v_instance_id UUID;
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

  -- Get instance_id from an existing user
  SELECT instance_id INTO v_instance_id 
  FROM auth.users 
  WHERE instance_id IS NOT NULL 
  LIMIT 1;

  IF v_instance_id IS NULL THEN
    RAISE EXCEPTION 'No valid instance_id found';
  END IF;

  -- Create auth user with the same ID
  BEGIN
    INSERT INTO auth.users (
      id,
      instance_id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_sent_at,
      confirmed_at,
      last_sign_in_at,
      is_super_admin
    )
    VALUES (
      NEW.id,
      v_instance_id,
      'authenticated',
      'authenticated',
      NEW.email,
      crypt(NEW.pin, gen_salt('bf')),
      NOW(),
      jsonb_build_object(
        'provider', 'email',
        'providers', ARRAY['email'],
        'role', 'employee'
      ),
      jsonb_build_object(
        'country', NEW.country,
        'timezone', NEW.timezone,
        'document_type', NEW.document_type,
        'document_number', NEW.document_number,
        'work_centers', NEW.work_centers,
        'job_positions', NEW.job_positions
      ),
      NOW(),
      NOW(),
      NOW(),
      NOW(),
      NOW(),
      false
    );
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'Email % already exists', NEW.email;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for employee import
CREATE TRIGGER handle_employee_import_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_import();

-- Create comprehensive policy for employee access
CREATE POLICY "employee_access_policy"
  ON employee_profiles
  FOR ALL
  TO authenticated
  USING (
    id = auth.uid() OR
    company_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = employee_profiles.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND employee_profiles.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND employee_profiles.delegation = ANY(sp.delegations))
      )
    )
  )
  WITH CHECK (
    id = auth.uid() OR
    company_id = auth.uid()
  );

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_email ON employee_profiles(email);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_company_id ON employee_profiles(company_id);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_is_active ON employee_profiles(is_active);