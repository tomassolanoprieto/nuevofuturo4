-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_employee_auth_trigger ON employee_profiles;
DROP FUNCTION IF EXISTS handle_employee_auth();

-- Create improved function with better error handling
CREATE OR REPLACE FUNCTION handle_employee_auth()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
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

  -- Check if auth user exists
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = NEW.email;

  IF v_user_id IS NOT NULL THEN
    -- Update existing auth user
    UPDATE auth.users 
    SET encrypted_password = crypt(NEW.pin, gen_salt('bf')),
        raw_app_meta_data = jsonb_build_object(
          'provider', 'email',
          'providers', ARRAY['email'],
          'role', 'employee'
        ),
        email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
        updated_at = NOW()
    WHERE id = v_user_id
    RETURNING id INTO NEW.id;
  ELSE
    -- Create new auth user with a new UUID
    INSERT INTO auth.users (
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      role
    )
    VALUES (
      NEW.email,
      crypt(NEW.pin, gen_salt('bf')),
      NOW(),
      jsonb_build_object(
        'provider', 'email',
        'providers', ARRAY['email'],
        'role', 'employee'
      ),
      '{}'::jsonb,
      NOW(),
      NOW(),
      'authenticated'
    )
    RETURNING id INTO NEW.id;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN others THEN
    RAISE EXCEPTION 'Error managing employee authentication: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create new trigger
CREATE TRIGGER handle_employee_auth_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_auth();

-- Update existing employees with proper auth entries
DO $$
DECLARE
  emp RECORD;
BEGIN
  FOR emp IN 
    SELECT * FROM employee_profiles 
    WHERE pin IS NOT NULL 
    AND email IS NOT NULL 
    AND is_active = true
  LOOP
    BEGIN
      -- Only update auth user if it exists
      UPDATE auth.users 
      SET encrypted_password = crypt(emp.pin, gen_salt('bf')),
          raw_app_meta_data = jsonb_build_object(
            'provider', 'email',
            'providers', ARRAY['email'],
            'role', 'employee'
          ),
          updated_at = NOW()
      WHERE email = emp.email;
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating employee %: %', emp.email, SQLERRM;
    END;
  END LOOP;
END;
$$;