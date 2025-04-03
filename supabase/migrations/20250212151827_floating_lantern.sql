-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS validate_supervisor_credentials(TEXT, TEXT);
DROP FUNCTION IF EXISTS get_supervisor_info(TEXT);

-- Create improved function to validate supervisor credentials
CREATE OR REPLACE FUNCTION validate_supervisor_credentials(
  p_email TEXT,
  p_pin TEXT
)
RETURNS TABLE (
  id UUID,
  fiscal_name TEXT,
  email TEXT,
  supervisor_type TEXT,
  work_centers work_center_enum[],
  delegations delegation_enum[],
  company_id UUID,
  is_active BOOLEAN
) AS $$
BEGIN
  -- Validate input
  IF p_email IS NULL OR p_pin IS NULL THEN
    RAISE EXCEPTION 'Email y PIN son obligatorios';
  END IF;

  -- Return supervisor info if credentials match
  RETURN QUERY
  SELECT 
    sp.id,
    sp.fiscal_name,
    sp.email,
    sp.supervisor_type,
    sp.work_centers,
    sp.delegations,
    sp.company_id,
    sp.is_active
  FROM supervisor_profiles sp
  WHERE sp.email = p_email 
  AND sp.pin = p_pin
  AND sp.is_active = true
  AND sp.supervisor_type = 'center';

  -- If no rows returned, credentials are invalid
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Credenciales inválidas';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create improved function to get supervisor info
CREATE OR REPLACE FUNCTION get_supervisor_info(p_email TEXT)
RETURNS TABLE (
  id UUID,
  fiscal_name TEXT,
  email TEXT,
  supervisor_type TEXT,
  work_centers work_center_enum[],
  delegations delegation_enum[],
  company_id UUID,
  is_active BOOLEAN
) AS $$
BEGIN
  -- Validate input
  IF p_email IS NULL THEN
    RAISE EXCEPTION 'Email es obligatorio';
  END IF;

  -- Return supervisor info
  RETURN QUERY
  SELECT 
    sp.id,
    sp.fiscal_name,
    sp.email,
    sp.supervisor_type,
    sp.work_centers,
    sp.delegations,
    sp.company_id,
    sp.is_active
  FROM supervisor_profiles sp
  WHERE sp.email = p_email
  AND sp.is_active = true;

  -- If no rows returned, supervisor not found
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Supervisor no encontrado';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if supervisor exists
CREATE OR REPLACE FUNCTION supervisor_exists(p_email TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM supervisor_profiles
    WHERE email = p_email
    AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create policy for supervisor authentication
CREATE POLICY "allow_supervisor_auth"
  ON supervisor_profiles
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_email_pin_active 
ON supervisor_profiles(email, pin, is_active);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_email_type_active 
ON supervisor_profiles(email, supervisor_type, is_active);

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION validate_supervisor_credentials TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_supervisor_info TO anon, authenticated;
GRANT EXECUTE ON FUNCTION supervisor_exists TO anon, authenticated;