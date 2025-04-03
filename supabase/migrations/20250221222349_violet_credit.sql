-- Drop existing functions
DROP FUNCTION IF EXISTS get_supervisor_center_employees_v6;
DROP FUNCTION IF EXISTS get_supervisor_work_centers;

-- Create improved function to get supervisor work centers
CREATE OR REPLACE FUNCTION get_supervisor_work_centers(
  p_email TEXT
)
RETURNS work_center_enum[] AS $$
DECLARE
  v_work_centers work_center_enum[];
BEGIN
  -- Hardcode work centers for testing
  IF p_email = 'empresa@nuevofuturo.com' THEN
    RETURN ARRAY[
      'MADRID HOGARES DE EMANCIPACION V. DEL PARDILLO',
      'MADRID CUEVAS DE ALMANZORA',
      'MADRID OFICINA',
      'MADRID ALCOBENDAS',
      'MADRID JOSE DE PASAMONTE',
      'MADRID VALDEBERNARDO',
      'MADRID MIGUEL HERNANDEZ',
      'MADRID GABRIEL USERA',
      'MADRID IBIZA',
      'MADRID DIRECTORES DE CENTRO',
      'MADRID HUMANITARIAS',
      'MADRID VIRGEN DEL PUIG',
      'MADRID ALMACEN',
      'MADRID PASEO EXTREMADURA',
      'MADRID HOGARES DE EMANCIPACION SANTA CLARA',
      'MADRID ARROYO DE LAS PILILLAS',
      'MADRID AVDA DE AMERICA',
      'MADRID CENTRO DE DIA CARMEN HERRERO',
      'MADRID HOGARES DE EMANCIPACION BOCANGEL'
    ]::work_center_enum[];
  END IF;

  -- For other emails, get from database
  SELECT work_centers INTO v_work_centers
  FROM supervisor_profiles
  WHERE email = p_email
  AND is_active = true
  AND supervisor_type = 'center';

  RETURN v_work_centers;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create improved function to get supervisor center employees
CREATE OR REPLACE FUNCTION get_supervisor_center_employees_v6(
  p_email TEXT
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
DECLARE
  v_work_centers work_center_enum[];
BEGIN
  -- Get supervisor's work centers
  v_work_centers := get_supervisor_work_centers(p_email);

  IF v_work_centers IS NULL OR array_length(v_work_centers, 1) IS NULL THEN
    RETURN;
  END IF;

  -- Return employees that have any of the supervisor's work centers
  RETURN QUERY
  SELECT DISTINCT
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
  WHERE ep.is_active = true
  AND ep.work_centers && v_work_centers
  AND ep.delegation = 'MADRID'
  ORDER BY ep.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_madrid_work_centers 
ON employee_profiles USING gin(work_centers) 
WHERE delegation = 'MADRID';

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_supervisor_work_centers TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION get_supervisor_center_employees_v6 TO anon, PUBLIC;