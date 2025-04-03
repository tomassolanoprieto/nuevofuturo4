-- Drop all existing policies for company_profiles
DROP POLICY IF EXISTS "Companies can view own profile" ON company_profiles;
DROP POLICY IF EXISTS "Companies can update own profile" ON company_profiles;
DROP POLICY IF EXISTS "Allow company registration" ON company_profiles;
DROP POLICY IF EXISTS "Public can view basic company info" ON company_profiles;

-- Disable RLS for company_profiles
ALTER TABLE company_profiles DISABLE ROW LEVEL SECURITY;