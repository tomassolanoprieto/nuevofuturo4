-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;
DROP FUNCTION IF EXISTS handle_supervisor_auth();

-- Drop and recreate supervisor_profiles table to match employee_profiles
DROP TABLE IF EXISTS supervisor_profiles CASCADE;

CREATE TABLE supervisor_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fiscal_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  country TEXT NOT NULL DEFAULT 'España',
  timezone TEXT NOT NULL DEFAULT 'Europe/Madrid',
  company_id UUID REFERENCES company_profiles(id),
  roles TEXT[] DEFAULT ARRAY['supervisor'],
  is_active BOOLEAN DEFAULT true,
  document_type TEXT CHECK (document_type IN ('DNI', 'NIE', 'Pasaporte')),
  document_number TEXT,
  work_center TEXT,
  pin TEXT NOT NULL CHECK (pin ~ '^\d{6}$'),
  employee_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE supervisor_profiles ENABLE ROW LEVEL SECURITY;

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

-- Create supervisor authentication function that matches employee auth
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

-- Create trigger
CREATE TRIGGER handle_supervisor_auth_trigger
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_auth();