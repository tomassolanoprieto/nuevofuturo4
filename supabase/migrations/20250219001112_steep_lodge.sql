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
  -- Validate input
  IF p_email IS NULL OR p_pin IS NULL THEN
    RAISE EXCEPTION 'Email y PIN son obligatorios';
  END IF;

  -- Return employee info if credentials match
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

  -- If no rows returned, credentials are invalid
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Credenciales inválidas';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create policy for employee authentication
CREATE POLICY "allow_employee_auth"
  ON employee_profiles
  FOR SELECT
  TO anon, PUBLIC
  USING (true);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_email_pin_active 
ON employee_profiles(email, pin, is_active);

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION verify_employee_credentials TO anon, PUBLIC;