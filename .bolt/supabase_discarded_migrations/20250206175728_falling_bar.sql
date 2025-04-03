-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_employee_import_trigger ON employee_profiles;
DROP FUNCTION IF EXISTS handle_employee_import();

-- Create improved employee import function that avoids rate limits
CREATE OR REPLACE FUNCTION handle_employee_import()
RETURNS TRIGGER AS $$
DECLARE
  v_instance_id UUID;
  v_user_id UUID;
BEGIN
  -- Basic validation
  IF NEW.email IS NULL THEN
    RAISE EXCEPTION 'Email is required';
  END IF;

  IF NEW.pin IS NULL THEN
    RAISE EXCEPTION 'PIN must be exactly 6 digits';
  END IF;

  IF NEW.pin !~ '^\d{6}$' THEN
    RAISE EXCEPTION 'PIN must be exactly 6 digits';
  END IF;

  -- Check if user already exists
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = NEW.email;

  -- Get instance_id from an existing user
  SELECT instance_id INTO v_instance_id 
  FROM auth.users 
  WHERE instance_id IS NOT NULL 
  LIMIT 1;

  IF v_user_id IS NOT NULL THEN
    -- Use existing user's ID
    NEW.id := v_user_id;
    
    -- Update existing auth user
    UPDATE auth.users 
    SET 
      encrypted_password = crypt(NEW.pin, gen_salt('bf')),
      email_confirmed_at = NOW(),
      confirmation_sent_at = NOW(),
      confirmed_at = NOW(),
      raw_app_meta_data = jsonb_build_object(
        'provider', 'email',
        'providers', ARRAY['email'],
        'role', 'employee'
      ),
      raw_user_meta_data = jsonb_build_object(
        'country', NEW.country,
        'timezone', NEW.timezone
      ),
      updated_at = NOW()
    WHERE id = v_user_id;
  ELSE
    -- Generate new UUID for new user
    NEW.id := gen_random_uuid();

    -- Create auth user without sending confirmation email
    INSERT INTO auth.users (
      id,
      instance_id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      confirmation_sent_at,
      confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at
    )
    VALUES (
      NEW.id,
      v_instance_id,
      'authenticated',
      'authenticated',
      NEW.email,
      crypt(NEW.pin, gen_salt('bf')),
      NOW(),
      NOW(),
      NOW(),
      jsonb_build_object(
        'provider', 'email',
        'providers', ARRAY['email'],
        'role', 'employee'
      ),
      jsonb_build_object(
        'country', NEW.country,
        'timezone', NEW.timezone
      ),
      NOW(),
      NOW()
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for employee import
CREATE TRIGGER handle_employee_import_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_import();

-- Drop existing policy if exists
DROP POLICY IF EXISTS "Allow employee import" ON employee_profiles;
DROP POLICY IF EXISTS "employee_import_policy" ON employee_profiles;

-- Create policy for employee import with a unique name
CREATE POLICY "employee_bulk_import_policy"
  ON employee_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM company_profiles
      WHERE company_profiles.id = auth.uid()
    )
  );