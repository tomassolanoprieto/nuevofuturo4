-- Drop existing policies if they exist
DROP POLICY IF EXISTS "allow_employee_login" ON employee_profiles;

-- Create policy that allows anonymous access for login
CREATE POLICY "allow_employee_login"
  ON employee_profiles
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Create or replace function to verify employee credentials
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
  -- Log attempt
  RAISE NOTICE 'Attempting to verify credentials for email: %', p_email;

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
  AND ep.is_active = true;

  -- Log result
  IF FOUND THEN
    RAISE NOTICE 'Credentials verified successfully for %', p_email;
  ELSE
    RAISE NOTICE 'Invalid credentials for %', p_email;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create index for better performance if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_employee_profiles_email_pin 
ON employee_profiles(email, pin);

-- Create index for active status if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_employee_profiles_is_active 
ON employee_profiles(is_active);

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION verify_employee_credentials TO anon, authenticated;