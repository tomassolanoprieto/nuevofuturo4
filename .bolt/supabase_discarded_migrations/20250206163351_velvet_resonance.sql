-- Add email column to company_profiles
ALTER TABLE company_profiles
ADD COLUMN IF NOT EXISTS email TEXT UNIQUE;

-- Create index for email lookups
CREATE INDEX IF NOT EXISTS idx_company_profiles_email 
ON company_profiles(email);

-- Update existing companies with their auth email
DO $$
DECLARE
  comp RECORD;
BEGIN
  FOR comp IN 
    SELECT cp.id, au.email 
    FROM company_profiles cp
    JOIN auth.users au ON au.id = cp.id
  LOOP
    UPDATE company_profiles
    SET email = comp.email
    WHERE id = comp.id;
  END LOOP;
END;
$$;

-- Make email required after updating existing records
ALTER TABLE company_profiles
ALTER COLUMN email SET NOT NULL;