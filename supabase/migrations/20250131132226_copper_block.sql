-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;
DROP FUNCTION IF EXISTS handle_supervisor_auth();

-- Create improved supervisor authentication function
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

  -- Validate supervisor type and assignments
  IF NEW.supervisor_type = 'center' AND array_length(NEW.work_centers, 1) IS NULL THEN
    RAISE EXCEPTION 'Work centers are required for center supervisors';
  END IF;

  IF NEW.supervisor_type = 'delegation' AND array_length(NEW.delegations, 1) IS NULL THEN
    RAISE EXCEPTION 'Delegations are required for delegation supervisors';
  END IF;

  -- Generate new UUID for the supervisor
  NEW.id := gen_random_uuid();

  -- Create auth user with minimal required fields
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
      'role', 'supervisor'
    ),
    'authenticated'
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
CREATE TRIGGER handle_supervisor_auth_trigger
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_auth();

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS supervisor_profiles_type_idx ON supervisor_profiles(supervisor_type);
CREATE INDEX IF NOT EXISTS supervisor_profiles_work_centers_idx ON supervisor_profiles USING gin(work_centers);
CREATE INDEX IF NOT EXISTS supervisor_profiles_delegations_idx ON supervisor_profiles USING gin(delegations);