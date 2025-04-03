-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_employee_auth_trigger ON employee_profiles;
DROP FUNCTION IF EXISTS handle_employee_auth();

-- Create improved function with better error handling
CREATE OR REPLACE FUNCTION handle_employee_auth()
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

  -- Create new auth user
  INSERT INTO auth.users (
    id,  -- Use the same ID as the profile
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
    NEW.id,  -- Use the same ID that was generated for the profile
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
  );

  RETURN NEW;
EXCEPTION
  WHEN others THEN
    -- If there's an error, try to update existing user instead
    UPDATE auth.users 
    SET encrypted_password = crypt(NEW.pin, gen_salt('bf')),
        raw_app_meta_data = jsonb_build_object(
          'provider', 'email',
          'providers', ARRAY['email'],
          'role', 'employee'
        ),
        updated_at = NOW()
    WHERE email = NEW.email;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create new trigger
CREATE TRIGGER handle_employee_auth_trigger
  AFTER INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_auth();