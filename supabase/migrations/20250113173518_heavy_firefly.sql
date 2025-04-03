-- Drop existing supervisor_profiles table and related objects
DROP TABLE IF EXISTS supervisor_profiles CASCADE;

-- Recreate supervisor_profiles table with proper auth.users reference
CREATE TABLE supervisor_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fiscal_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  work_centers TEXT[] NOT NULL,
  pin TEXT NOT NULL,
  company_id UUID REFERENCES company_profiles(id),
  document_type TEXT CHECK (document_type IN ('DNI', 'NIE', 'Pasaporte')),
  document_number TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT pin_format CHECK (pin ~ '^\d{6}$')
);

-- Enable RLS
ALTER TABLE supervisor_profiles ENABLE ROW LEVEL SECURITY;

-- Create simplified policies for supervisor access
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

-- Create function to handle supervisor authentication
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

  -- Check if user exists by email
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = NEW.email;

  IF v_user_id IS NOT NULL THEN
    -- Use existing user's ID
    NEW.id := v_user_id;
  ELSE
    -- Generate new UUID if user doesn't exist
    NEW.id := gen_random_uuid();
  END IF;

  -- Create or update auth user
  INSERT INTO auth.users (
    id,
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
    NEW.id,
    NEW.email,
    crypt(NEW.pin, gen_salt('bf')),
    NOW(),
    jsonb_build_object(
      'provider', 'email',
      'providers', ARRAY['email'],
      'role', 'supervisor'
    ),
    jsonb_build_object(
      'work_centers', NEW.work_centers,
      'document_type', NEW.document_type,
      'document_number', NEW.document_number
    ),
    NOW(),
    NOW(),
    'authenticated'
  )
  ON CONFLICT (id) DO UPDATE
  SET encrypted_password = crypt(NEW.pin, gen_salt('bf')),
      raw_app_meta_data = jsonb_build_object(
        'provider', 'email',
        'providers', ARRAY['email'],
        'role', 'supervisor'
      ),
      raw_user_meta_data = jsonb_build_object(
        'work_centers', NEW.work_centers,
        'document_type', NEW.document_type,
        'document_number', NEW.document_number
      ),
      updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for supervisor authentication
CREATE TRIGGER handle_supervisor_auth_trigger
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_auth();

-- Add policy for supervisors to access employee data
CREATE POLICY "Supervisors can view employee data"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = employee_profiles.company_id
      AND sp.is_active = true
      AND employee_profiles.work_center = ANY(sp.work_centers)
    )
  );

-- Update existing supervisors
DO $$
DECLARE
  sup RECORD;
BEGIN
  FOR sup IN 
    SELECT * FROM supervisor_profiles 
    WHERE is_active = true
  LOOP
    BEGIN
      -- Create or update auth entries
      INSERT INTO auth.users (
        id,
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
        sup.id,
        sup.email,
        crypt(sup.pin, gen_salt('bf')),
        NOW(),
        jsonb_build_object(
          'provider', 'email',
          'providers', ARRAY['email'],
          'role', 'supervisor'
        ),
        jsonb_build_object(
          'work_centers', sup.work_centers,
          'document_type', COALESCE(sup.document_type, 'DNI'),
          'document_number', COALESCE(sup.document_number, '')
        ),
        sup.created_at,
        NOW(),
        'authenticated'
      )
      ON CONFLICT (id) DO UPDATE
      SET encrypted_password = crypt(sup.pin, gen_salt('bf')),
          raw_app_meta_data = jsonb_build_object(
            'provider', 'email',
            'providers', ARRAY['email'],
            'role', 'supervisor'
          ),
          raw_user_meta_data = jsonb_build_object(
            'work_centers', sup.work_centers,
            'document_type', COALESCE(sup.document_type, 'DNI'),
            'document_number', COALESCE(sup.document_number, '')
          ),
          updated_at = NOW();
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating supervisor %: %', sup.email, SQLERRM;
    END;
  END LOOP;
END;
$$;