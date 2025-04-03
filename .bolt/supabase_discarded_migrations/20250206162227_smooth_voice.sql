-- Drop existing policies
DROP POLICY IF EXISTS "Companies can view own profile" ON company_profiles;
DROP POLICY IF EXISTS "Companies can update own profile" ON company_profiles;
DROP POLICY IF EXISTS "Allow company registration" ON company_profiles;
DROP POLICY IF EXISTS "Public can view basic company info" ON company_profiles;

-- Create comprehensive policies for company_profiles
CREATE POLICY "Companies can view own profile"
  ON company_profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

CREATE POLICY "Companies can update own profile"
  ON company_profiles
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid());

CREATE POLICY "Allow company registration"
  ON company_profiles
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    fiscal_name IS NOT NULL AND
    country IS NOT NULL AND
    timezone IS NOT NULL
  );

-- Create policy for public company info
CREATE POLICY "Public can view basic company info"
  ON company_profiles
  FOR SELECT
  TO anon, authenticated
  USING (true);