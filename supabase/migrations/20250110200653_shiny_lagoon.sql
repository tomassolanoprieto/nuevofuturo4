-- Drop existing trigger
DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;

-- Create or replace supervisor authentication function
CREATE OR REPLACE FUNCTION handle_supervisor_auth()
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

  -- Check if auth user exists
  IF EXISTS (
    SELECT 1 FROM auth.users WHERE email = NEW.email
  ) THEN
    -- Update existing auth user's password
    UPDATE auth.users 
    SET encrypted_password = crypt(NEW.pin, gen_salt('bf')),
        raw_app_meta_data = jsonb_build_object(
          'provider', 'email',
          'providers', ARRAY['email'],
          'role', 'supervisor'
        ),
        raw_user_meta_data = jsonb_build_object(
          'work_centers', NEW.work_centers
        ),
        updated_at = NOW()
    WHERE email = NEW.email
    RETURNING id INTO NEW.id;
  ELSE
    -- Create new auth user
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
        'role', 'supervisor'
      ),
      jsonb_build_object(
        'work_centers', NEW.work_centers
      ),
      NOW(),
      NOW(),
      'authenticated'
    )
    RETURNING id INTO NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create new trigger that runs BEFORE INSERT
CREATE TRIGGER handle_supervisor_auth_trigger
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_auth();