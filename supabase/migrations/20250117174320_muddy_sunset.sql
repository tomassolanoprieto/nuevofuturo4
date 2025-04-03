-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;
DROP FUNCTION IF EXISTS handle_supervisor_auth();

-- Drop and recreate supervisor_profiles table with simpler structure
DROP TABLE IF EXISTS supervisor_profiles;

CREATE TABLE supervisor_profiles (
  id UUID PRIMARY KEY,
  fiscal_name TEXT NOT NULL,
  email TEXT NOT NULL,
  document_type TEXT CHECK (document_type IN ('DNI', 'NIE', 'Pasaporte')),
  document_number TEXT,
  work_center TEXT NOT NULL,
  company_id UUID REFERENCES company_profiles(id),
  pin TEXT NOT NULL CHECK (pin ~ '^\d{6}$'),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE supervisor_profiles ENABLE ROW LEVEL SECURITY;

-- Create simplified policies
CREATE POLICY "Companies can manage supervisors"
  ON supervisor_profiles
  FOR ALL
  TO authenticated
  USING (company_id = auth.uid())
  WITH CHECK (company_id = auth.uid());

CREATE POLICY "Supervisors can view own profile"
  ON supervisor_profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Create simplified supervisor authentication function
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

  -- Create auth user with minimal required fields
  INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    role,
    raw_app_meta_data
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
    )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
CREATE TRIGGER handle_supervisor_auth_trigger
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_auth();