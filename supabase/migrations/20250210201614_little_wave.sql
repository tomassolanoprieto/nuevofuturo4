-- Drop existing policies
DROP POLICY IF EXISTS "employee_profiles_access_policy_v9" ON employee_profiles;
DROP POLICY IF EXISTS "employee_profiles_access_policy_v8" ON employee_profiles;
DROP POLICY IF EXISTS "employee_profiles_access_policy_v7" ON employee_profiles;
DROP POLICY IF EXISTS "employee_profiles_access_policy_v6" ON employee_profiles;
DROP POLICY IF EXISTS "employee_profiles_access_policy_v5" ON employee_profiles;

-- Create policy that allows anonymous access for login
CREATE POLICY "allow_employee_login"
  ON employee_profiles
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Create function to verify employee credentials
CREATE OR REPLACE FUNCTION verify_employee_credentials(
  p_email TEXT,
  p_pin TEXT
)
RETURNS TABLE (
  id UUID,
  fiscal_name TEXT,
  email TEXT,
  work_centers work_center_enum[],
  delegation delegation_enum,
  is_active BOOLEAN,
  company_id UUID
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ep.id,
    ep.fiscal_name,
    ep.email,
    ep.work_centers,
    ep.delegation,
    ep.is_active,
    ep.company_id
  FROM employee_profiles ep
  WHERE ep.email = p_email 
  AND ep.pin = p_pin
  AND ep.is_active = true
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get employee info by email
CREATE OR REPLACE FUNCTION get_employee_info(p_email TEXT)
RETURNS TABLE (
  id UUID,
  fiscal_name TEXT,
  email TEXT,
  work_centers work_center_enum[],
  delegation delegation_enum,
  is_active BOOLEAN,
  company_id UUID
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ep.id,
    ep.fiscal_name,
    ep.email,
    ep.work_centers,
    ep.delegation,
    ep.is_active,
    ep.company_id
  FROM employee_profiles ep
  WHERE ep.email = p_email
  AND ep.is_active = true
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if employee exists
CREATE OR REPLACE FUNCTION employee_exists(p_email TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM employee_profiles
    WHERE email = p_email
    AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_email_pin 
ON employee_profiles(email, pin);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_email_active 
ON employee_profiles(email, is_active);