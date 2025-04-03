-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own company profile" ON company_profiles;
DROP POLICY IF EXISTS "Users can update own company profile" ON company_profiles;
DROP POLICY IF EXISTS "Users can insert own company profile" ON company_profiles;

-- Create improved policies for company_profiles
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
  TO authenticated
  WITH CHECK (
    -- Allow insert if the ID matches the authenticated user
    id = auth.uid() AND
    -- Basic validation
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