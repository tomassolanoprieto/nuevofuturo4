-- Drop existing function if exists
DROP FUNCTION IF EXISTS validate_supervisor_credentials(TEXT, TEXT);

-- Create improved supervisor validation function
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

-- Create function to get employees by work center
CREATE OR REPLACE FUNCTION get_employees_by_work_center(
  p_work_center work_center_enum
)
RETURNS TABLE (
  id UUID,
  fiscal_name TEXT,
  email TEXT,
  work_centers work_center_enum[],
  delegation delegation_enum,
  document_type TEXT,
  document_number TEXT,
  job_positions job_position_enum[],
  employee_id TEXT,
  seniority_date DATE,
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
    ep.document_type,
    ep.document_number,
    ep.job_positions,
    ep.employee_id,
    ep.seniority_date,
    ep.is_active,
    ep.company_id
  FROM employee_profiles ep
  WHERE p_work_center = ANY(ep.work_centers)
  AND ep.is_active = true
  ORDER BY ep.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create policy for supervisor access
CREATE POLICY "allow_all_supervisor_access"
  ON supervisor_profiles
  FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Create policy for employee access
CREATE POLICY "allow_all_employee_access"
  ON employee_profiles
  FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers_gin 
ON employee_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_is_active 
ON employee_profiles(is_active);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_email_pin 
ON supervisor_profiles(email, pin);

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION validate_supervisor_credentials TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_employees_by_work_center TO anon, authenticated;