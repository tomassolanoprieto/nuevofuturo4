-- Create supervisor_profiles table
CREATE TABLE IF NOT EXISTS supervisor_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fiscal_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  country TEXT NOT NULL DEFAULT 'España',
  timezone TEXT NOT NULL DEFAULT 'Europe/Madrid',
  company_id UUID REFERENCES company_profiles(id),
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

-- Create policies
CREATE POLICY "Supervisors can view their own profile"
  ON supervisor_profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

CREATE POLICY "Companies can manage their supervisors"
  ON supervisor_profiles
  FOR ALL
  TO authenticated
  USING (company_id = auth.uid())
  WITH CHECK (company_id = auth.uid());

-- Create supervisor authentication function
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

  -- Create auth user with email confirmation
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