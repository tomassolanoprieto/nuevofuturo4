-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS get_employees_by_delegation(delegation_enum);
DROP FUNCTION IF EXISTS get_delegation_employees(UUID);
DROP FUNCTION IF EXISTS get_delegation_employees_v3(UUID);
DROP FUNCTION IF EXISTS get_delegation_employees_v4(UUID);
DROP FUNCTION IF EXISTS get_delegation_employees_v5(UUID);

-- Create function to get employees by delegation
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
  WHERE ep.delegation = p_delegation
  AND ep.is_active = true
  ORDER BY ep.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to validate delegation access
CREATE OR REPLACE FUNCTION validate_delegation_access(
  p_email TEXT,
  p_pin TEXT,
  p_delegation delegation_enum
)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    -- Map hardcoded credentials to delegations
    (p_email = 'delegacion_cordoba@nuevofuturo.com' AND p_pin = '285975' AND p_delegation = 'CORDOBA') OR
    (p_email = 'delegacion_palencia@nuevofuturo.com' AND p_pin = '780763' AND p_delegation = 'PALENCIA') OR
    (p_email = 'delegacion_cadiz@nuevofuturo.com' AND p_pin = '573572' AND p_delegation = 'CADIZ') OR
    (p_email = 'delegacion_alicante@nuevofuturo.com' AND p_pin = '631180' AND p_delegation = 'ALICANTE') OR
    (p_email = 'delegacion_burgos@nuevofuturo.com' AND p_pin = '520499' AND p_delegation = 'BURGOS') OR
    (p_email = 'delegacion_murcia@nuevofuturo.com' AND p_pin = '942489' AND p_delegation = 'MURCIA') OR
    (p_email = 'delegacion_valladolid@nuevofuturo.com' AND p_pin = '931909' AND p_delegation = 'VALLADOLID') OR
    (p_email = 'delegacion_sevilla@nuevofuturo.com' AND p_pin = '129198' AND p_delegation = 'SEVILLA') OR
    (p_email = 'delegacion_santander@nuevofuturo.com' AND p_pin = '280062' AND p_delegation = 'SANTANDER') OR
    (p_email = 'delegacion_madrid@nuevofuturo.com' AND p_pin = '228738' AND p_delegation = 'MADRID') OR
    (p_email = 'delegacion_concepcion@nuevofuturo.com' AND p_pin = '670959' AND p_delegation = 'CONCEPCION_LA') OR
    (p_email = 'delegacion_alava@nuevofuturo.com' AND p_pin = '768381' AND p_delegation = 'ALAVA')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation 
ON employee_profiles(delegation);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_is_active 
ON employee_profiles(is_active);

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_employees_by_delegation TO PUBLIC;
GRANT EXECUTE ON FUNCTION validate_delegation_access TO PUBLIC;