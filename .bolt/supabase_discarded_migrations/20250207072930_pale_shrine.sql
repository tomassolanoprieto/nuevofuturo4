-- Drop existing trigger and function if they exist
DROP TRIGGER IF EXISTS handle_employee_import_trigger ON employee_profiles;
DROP FUNCTION IF EXISTS handle_employee_import();

-- Create improved employee import function
CREATE OR REPLACE FUNCTION handle_employee_import()
RETURNS TRIGGER AS $$
DECLARE
  v_instance_id UUID;
  v_user_id UUID;
  v_pin TEXT;
BEGIN
  -- Basic validation
  IF NEW.email IS NULL THEN
    RAISE EXCEPTION 'Email is required';
  END IF;

  -- Generate 6-digit PIN if not provided
  IF NEW.pin IS NULL THEN
    v_pin := LPAD(floor(random() * 1000000)::text, 6, '0');
    NEW.pin := v_pin;
  END IF;

  -- Validate PIN format
  IF NEW.pin !~ '^\d{6}$' THEN
    RAISE EXCEPTION 'PIN must be exactly 6 digits';
  END IF;

  -- Set default values if not provided
  NEW.country := COALESCE(NEW.country, 'España');
  NEW.timezone := COALESCE(NEW.timezone, 'Europe/Madrid');
  NEW.is_active := COALESCE(NEW.is_active, true);

  -- Convert work centers to array if string
  IF NEW.work_centers IS NULL OR array_length(NEW.work_centers, 1) IS NULL THEN
    NEW.work_centers := ARRAY[NEW.work_centers[1]]::work_center_enum[];
  END IF;

  -- Convert job positions to array if string
  IF NEW.job_positions IS NULL OR array_length(NEW.job_positions, 1) IS NULL THEN
    NEW.job_positions := ARRAY[NEW.job_positions[1]]::job_position_enum[];
  END IF;

  -- Check if user exists by email
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = NEW.email;

  IF v_user_id IS NOT NULL THEN
    -- Use existing user's ID
    NEW.id := v_user_id;
  ELSE
    -- Generate new UUID if user doesn't exist
    NEW.id := gen_random_uuid();
  END IF;

  -- Get instance_id from an existing user
  SELECT instance_id INTO v_instance_id 
  FROM auth.users 
  WHERE instance_id IS NOT NULL 
  LIMIT 1;

  IF v_instance_id IS NULL THEN
    RAISE EXCEPTION 'No valid instance_id found';
  END IF;

  -- Create or update auth user
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
    last_sign_in_at
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
    COALESCE(NEW.created_at, NOW()),
    NOW(),
    NOW(),
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET 
    encrypted_password = EXCLUDED.encrypted_password,
    email_confirmed_at = EXCLUDED.email_confirmed_at,
    raw_app_meta_data = EXCLUDED.raw_app_meta_data,
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    updated_at = EXCLUDED.updated_at,
    confirmation_sent_at = EXCLUDED.confirmation_sent_at,
    confirmed_at = EXCLUDED.confirmed_at,
    last_sign_in_at = EXCLUDED.last_sign_in_at;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for employee import
CREATE TRIGGER handle_employee_import_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_import();

-- Create policy for employee import
CREATE POLICY "employee_import_policy"
  ON employee_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM company_profiles
      WHERE company_profiles.id = auth.uid()
    )
  );