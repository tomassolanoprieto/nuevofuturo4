-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS validate_delegation_access(TEXT, TEXT);
DROP FUNCTION IF EXISTS get_employees_by_delegation(TEXT);

-- Create function to validate delegation access (hardcoded to MADRID)
CREATE OR REPLACE FUNCTION validate_delegation_access(
  p_email TEXT,
  p_pin TEXT
)
RETURNS delegation_enum AS $$
BEGIN
  -- Only allow access with Madrid credentials
  IF p_email = 'delegacion_madrid@nuevofuturo.com' AND p_pin = '228738' THEN
    RETURN 'MADRID'::delegation_enum;
  END IF;
  
  RAISE EXCEPTION 'Credenciales inválidas';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get employees by delegation (hardcoded to MADRID)
CREATE OR REPLACE FUNCTION get_employees_by_delegation(
  p_delegation delegation_enum
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
  -- Only return Madrid employees regardless of input delegation
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
  WHERE ep.delegation = 'MADRID'
  AND ep.is_active = true
  ORDER BY ep.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_madrid_delegation 
ON employee_profiles(delegation) 
WHERE delegation = 'MADRID';

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION validate_delegation_access TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION get_employees_by_delegation TO anon, PUBLIC;