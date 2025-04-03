-- Drop existing policies first
DROP POLICY IF EXISTS "company_profiles_access_v1" ON company_profiles;
DROP POLICY IF EXISTS "allow_all_company_operations" ON company_profiles;

-- Create simple policy with unique name
CREATE POLICY "company_profiles_access_v2"
  ON company_profiles
  FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_company_profiles_fiscal_name ON company_profiles(fiscal_name);

-- Make sure id is UUID and has default
ALTER TABLE company_profiles
ALTER COLUMN id SET DEFAULT gen_random_uuid();