-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS confirm_company_email ON company_profiles;
DROP FUNCTION IF EXISTS auto_confirm_email();
DROP TRIGGER IF EXISTS handle_company_registration_trigger ON company_profiles;
DROP FUNCTION IF EXISTS handle_company_registration();

-- Create improved company registration function
CREATE OR REPLACE FUNCTION handle_company_registration()
RETURNS TRIGGER AS $$
BEGIN
  -- Basic validation
  IF NEW.email IS NULL THEN
    RAISE EXCEPTION 'Email is required';
  END IF;

  IF NEW.fiscal_name IS NULL THEN
    RAISE EXCEPTION 'Fiscal name is required';
  END IF;

  -- Set default values if not provided
  NEW.country := COALESCE(NEW.country, 'España');
  NEW.timezone := COALESCE(NEW.timezone, 'Europe/Madrid');
  NEW.roles := ARRAY['company'];
  NEW.created_at := NOW();
  NEW.updated_at := NOW();

  -- Automatically confirm email for the auth user
  UPDATE auth.users
  SET 
    email_confirmed_at = NOW(),
    raw_app_meta_data = jsonb_build_object(
      'provider', 'email',
      'providers', ARRAY['email'],
      'role', 'company'
    )
  WHERE id = NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for company registration
CREATE TRIGGER handle_company_registration_trigger
  BEFORE INSERT ON company_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_company_registration();

-- Drop existing policies
DROP POLICY IF EXISTS "Allow company registration" ON company_profiles;
DROP POLICY IF EXISTS "Companies can access own profile" ON company_profiles;

-- Create comprehensive policies for company access
CREATE POLICY "company_access_policy"
  ON company_profiles
  FOR ALL
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

CREATE POLICY "company_registration_policy"
  ON company_profiles
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_company_profiles_email ON company_profiles(email);
CREATE INDEX IF NOT EXISTS idx_company_profiles_fiscal_name ON company_profiles(fiscal_name);

-- Update existing companies
DO $$
DECLARE
  comp RECORD;
BEGIN
  FOR comp IN 
    SELECT cp.id, au.email 
    FROM company_profiles cp
    JOIN auth.users au ON au.id = cp.id
  LOOP
    -- Update company profile
    UPDATE company_profiles
    SET 
      email = COALESCE(comp.email, email),
      country = COALESCE(country, 'España'),
      timezone = COALESCE(timezone, 'Europe/Madrid'),
      roles = ARRAY['company'],
      updated_at = NOW()
    WHERE id = comp.id;

    -- Update auth user
    UPDATE auth.users
    SET 
      email_confirmed_at = NOW(),
      raw_app_meta_data = jsonb_build_object(
        'provider', 'email',
        'providers', ARRAY['email'],
        'role', 'company'
      )
    WHERE id = comp.id;
  END LOOP;
END;
$$;