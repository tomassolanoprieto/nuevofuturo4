-- Drop existing policies
DROP POLICY IF EXISTS "Allow anonymous registration" ON company_profiles;
DROP POLICY IF EXISTS "Allow authenticated access" ON company_profiles;

-- Ensure company_profiles has all required fields
ALTER TABLE company_profiles
ADD COLUMN IF NOT EXISTS email TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS country TEXT,
ADD COLUMN IF NOT EXISTS timezone TEXT,
ADD COLUMN IF NOT EXISTS roles TEXT[] DEFAULT ARRAY['company'];

-- Make required fields NOT NULL
ALTER TABLE company_profiles
ALTER COLUMN email SET NOT NULL,
ALTER COLUMN fiscal_name SET NOT NULL,
ALTER COLUMN country SET NOT NULL,
ALTER COLUMN timezone SET NOT NULL;

-- Create comprehensive policies
CREATE POLICY "Allow company registration"
  ON company_profiles
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    fiscal_name IS NOT NULL AND
    email IS NOT NULL AND
    country IS NOT NULL AND
    timezone IS NOT NULL
  );

CREATE POLICY "Companies can access own profile"
  ON company_profiles
  FOR ALL
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_company_profiles_email ON company_profiles(email);
CREATE INDEX IF NOT EXISTS idx_company_profiles_fiscal_name ON company_profiles(fiscal_name);

-- Update existing companies with auth data
DO $$
DECLARE
  comp RECORD;
BEGIN
  FOR comp IN 
    SELECT cp.id, au.email 
    FROM company_profiles cp
    JOIN auth.users au ON au.id = cp.id
    WHERE cp.email IS NULL
  LOOP
    UPDATE company_profiles
    SET 
      email = comp.email,
      country = COALESCE(country, 'España'),
      timezone = COALESCE(timezone, 'Europe/Madrid')
    WHERE id = comp.id;
  END LOOP;
END;
$$;