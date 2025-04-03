-- Drop existing policies
DROP POLICY IF EXISTS "company_access_policy" ON company_profiles;
DROP POLICY IF EXISTS "company_registration_policy" ON company_profiles;
DROP POLICY IF EXISTS "Companies can access own profile" ON company_profiles;
DROP POLICY IF EXISTS "Allow company registration" ON company_profiles;

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_company_registration_trigger ON company_profiles;
DROP FUNCTION IF EXISTS handle_company_registration();

-- Drop auth.users foreign key constraint if exists
ALTER TABLE company_profiles 
DROP CONSTRAINT IF EXISTS company_profiles_id_fkey CASCADE;

-- Create simple policy that allows all operations
CREATE POLICY "allow_all_company_operations"
  ON company_profiles
  FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_company_profiles_id ON company_profiles(id);
CREATE INDEX IF NOT EXISTS idx_company_profiles_fiscal_name ON company_profiles(fiscal_name);

-- Set default values for required fields
ALTER TABLE company_profiles
ADD COLUMN IF NOT EXISTS country TEXT DEFAULT 'España',
ADD COLUMN IF NOT EXISTS timezone TEXT DEFAULT 'Europe/Madrid',
ADD COLUMN IF NOT EXISTS roles TEXT[] DEFAULT ARRAY['company'];

-- Make sure id is UUID and has default
ALTER TABLE company_profiles
ALTER COLUMN id SET DEFAULT gen_random_uuid();