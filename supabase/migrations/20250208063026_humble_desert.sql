-- Drop existing policies
DROP POLICY IF EXISTS "allow_all_company_operations" ON company_profiles;

-- Add missing columns to company_profiles
ALTER TABLE company_profiles
ADD COLUMN IF NOT EXISTS email TEXT,
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS country TEXT,
ADD COLUMN IF NOT EXISTS timezone TEXT,
ADD COLUMN IF NOT EXISTS roles TEXT[];

-- Set default values for existing rows
UPDATE company_profiles
SET 
  email = COALESCE(email, fiscal_name || '@company.com'),
  country = COALESCE(country, 'España'),
  timezone = COALESCE(timezone, 'Europe/Madrid'),
  roles = COALESCE(roles, ARRAY['company']);

-- Now add constraints
ALTER TABLE company_profiles
ADD CONSTRAINT company_profiles_email_unique UNIQUE (email),
ALTER COLUMN email SET NOT NULL,
ALTER COLUMN fiscal_name SET NOT NULL,
ALTER COLUMN country SET NOT NULL,
ALTER COLUMN timezone SET NOT NULL;

-- Create simple policy that allows all operations
CREATE POLICY "company_profiles_access_v1"
  ON company_profiles
  FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_company_profiles_email ON company_profiles(email);
CREATE INDEX IF NOT EXISTS idx_company_profiles_fiscal_name ON company_profiles(fiscal_name);

-- Make sure id is UUID and has default
ALTER TABLE company_profiles
ALTER COLUMN id SET DEFAULT gen_random_uuid();