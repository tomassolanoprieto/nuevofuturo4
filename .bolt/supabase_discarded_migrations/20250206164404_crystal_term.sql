-- Create function to handle company registration
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

  -- Check if email already exists
  IF EXISTS (
    SELECT 1 FROM company_profiles WHERE email = NEW.email
  ) THEN
    RAISE EXCEPTION 'Email already exists';
  END IF;

  -- Set created_at and updated_at
  NEW.created_at := NOW();
  NEW.updated_at := NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for company registration
DROP TRIGGER IF EXISTS handle_company_registration_trigger ON company_profiles;
CREATE TRIGGER handle_company_registration_trigger
  BEFORE INSERT ON company_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_company_registration();

-- Create index for faster email lookups if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_company_profiles_email_unique 
ON company_profiles(email);