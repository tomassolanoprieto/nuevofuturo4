-- Drop existing policies
DROP POLICY IF EXISTS "Companies can manage supervisors" ON supervisor_profiles;
DROP POLICY IF EXISTS "Supervisors can view own profile" ON supervisor_profiles;

-- Create policies that match employee_profiles
CREATE POLICY "Users can view own supervisor profile"
  ON supervisor_profiles
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = id OR 
    EXISTS (
      SELECT 1 FROM company_profiles 
      WHERE company_profiles.id = auth.uid()
    )
  );

CREATE POLICY "Users can update own supervisor profile"
  ON supervisor_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can insert supervisor profile"
  ON supervisor_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = id OR
    EXISTS (
      SELECT 1 FROM company_profiles 
      WHERE company_profiles.id = auth.uid()
    )
  );

-- Update supervisor authentication function to match employee auth
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

  -- Generate new UUID for the supervisor
  NEW.id := gen_random_uuid();

  -- Create auth user with minimal required fields (like employee auth)
  INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    role
  )
  VALUES (
    NEW.id,
    NEW.email,
    crypt(NEW.pin, gen_salt('bf')),
    NOW(),
    'authenticated'
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger and recreate
DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;

CREATE TRIGGER handle_supervisor_auth_trigger
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_auth();