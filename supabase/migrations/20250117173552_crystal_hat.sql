-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;
DROP FUNCTION IF EXISTS handle_supervisor_auth();

-- Create improved supervisor authentication function
CREATE OR REPLACE FUNCTION handle_supervisor_auth()
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

  -- Generate new UUID for the supervisor
  NEW.id := gen_random_uuid();

  -- Create auth user
  INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    role,
    raw_app_meta_data,
    instance_id,
    aud
  )
  VALUES (
    NEW.id,
    NEW.email,
    crypt(NEW.pin, gen_salt('bf')),
    NOW(),
    'authenticated',
    jsonb_build_object(
      'provider', 'email',
      'providers', ARRAY['email'],
      'role', 'supervisor'
    ),
    (SELECT instance_id FROM auth.users WHERE instance_id IS NOT NULL LIMIT 1),
    'ydcqmnmblcmkcrdocoqn'
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create new trigger
CREATE TRIGGER handle_supervisor_auth_trigger
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_auth();