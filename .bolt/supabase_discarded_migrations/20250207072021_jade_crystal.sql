-- Drop existing trigger and function if they exist
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

  IF NEW.pin IS NULL THEN
    RAISE EXCEPTION 'PIN must be exactly 6 digits';
  END IF;

  IF NEW.pin !~ '^\d{6}$' THEN
    RAISE EXCEPTION 'PIN must be exactly 6 digits';
  END IF;

  -- Generate new UUID for the employee BEFORE creating auth user
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
  INSERT INTO auth.users (
    id,                      -- Use the same ID we generated
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,                  -- Use the same ID here
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
      'country', COALESCE(NEW.country, 'España'),
      'timezone', COALESCE(NEW.timezone, 'Europe/Madrid')
    ),
    NOW(),
    NOW()
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for employee import
CREATE TRIGGER handle_employee_import_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_import();

-- Update existing employees to ensure proper auth entries
DO $$
DECLARE
  emp RECORD;
  v_instance_id UUID;
BEGIN
  -- Get instance_id from an existing user
  SELECT instance_id INTO v_instance_id 
  FROM auth.users 
  WHERE instance_id IS NOT NULL 
  LIMIT 1;

  FOR emp IN 
    SELECT * FROM employee_profiles 
    WHERE is_active = true
  LOOP
    BEGIN
      -- Update or create auth user
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
        updated_at
      )
      VALUES (
        emp.id,
        v_instance_id,
        'authenticated',
        'authenticated',
        emp.email,
        crypt(emp.pin, gen_salt('bf')),
        NOW(),
        jsonb_build_object(
          'provider', 'email',
          'providers', ARRAY['email'],
          'role', 'employee'
        ),
        jsonb_build_object(
          'country', COALESCE(emp.country, 'España'),
          'timezone', COALESCE(emp.timezone, 'Europe/Madrid')
        ),
        emp.created_at,
        NOW()
      )
      ON CONFLICT (id) DO UPDATE
      SET 
        encrypted_password = EXCLUDED.encrypted_password,
        raw_app_meta_data = EXCLUDED.raw_app_meta_data,
        raw_user_meta_data = EXCLUDED.raw_user_meta_data,
        updated_at = NOW();
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating employee %: %', emp.email, SQLERRM;
    END;
  END LOOP;
END;
$$;