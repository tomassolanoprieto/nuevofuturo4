-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS get_employees_by_delegation(delegation_enum);
DROP FUNCTION IF EXISTS validate_delegation_access(TEXT, TEXT, delegation_enum);

-- Create function to get employees by delegation
CREATE OR REPLACE FUNCTION get_employees_by_delegation(
  p_delegation TEXT
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
  v_delegation delegation_enum;
BEGIN
  -- Convert input delegation to proper enum value
  v_delegation := CASE UPPER(p_delegation)
    WHEN 'CORDOBA' THEN 'CORDOBA'::delegation_enum
    WHEN 'PALENCIA' THEN 'PALENCIA'::delegation_enum
    WHEN 'CADIZ' THEN 'CADIZ'::delegation_enum
    WHEN 'ALICANTE' THEN 'ALICANTE'::delegation_enum
    WHEN 'BURGOS' THEN 'BURGOS'::delegation_enum
    WHEN 'MURCIA' THEN 'MURCIA'::delegation_enum
    WHEN 'VALLADOLID' THEN 'VALLADOLID'::delegation_enum
    WHEN 'SEVILLA' THEN 'SEVILLA'::delegation_enum
    WHEN 'SANTANDER' THEN 'SANTANDER'::delegation_enum
    WHEN 'MADRID' THEN 'MADRID'::delegation_enum
    WHEN 'CONCEPCION' THEN 'CONCEPCION_LA'::delegation_enum
    WHEN 'ALAVA' THEN 'ALAVA'::delegation_enum
    ELSE NULL
  END;

  IF v_delegation IS NULL THEN
    RAISE EXCEPTION 'Delegación no válida: %', p_delegation;
  END IF;

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
  WHERE ep.delegation = v_delegation
  AND ep.is_active = true
  ORDER BY ep.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to validate delegation access
CREATE OR REPLACE FUNCTION validate_delegation_access(
  p_email TEXT,
  p_pin TEXT
)
RETURNS TEXT AS $$
BEGIN
  RETURN CASE
    WHEN p_email = 'delegacion_cordoba@nuevofuturo.com' AND p_pin = '285975' THEN 'CORDOBA'
    WHEN p_email = 'delegacion_palencia@nuevofuturo.com' AND p_pin = '780763' THEN 'PALENCIA'
    WHEN p_email = 'delegacion_cadiz@nuevofuturo.com' AND p_pin = '573572' THEN 'CADIZ'
    WHEN p_email = 'delegacion_alicante@nuevofuturo.com' AND p_pin = '631180' THEN 'ALICANTE'
    WHEN p_email = 'delegacion_burgos@nuevofuturo.com' AND p_pin = '520499' THEN 'BURGOS'
    WHEN p_email = 'delegacion_murcia@nuevofuturo.com' AND p_pin = '942489' THEN 'MURCIA'
    WHEN p_email = 'delegacion_valladolid@nuevofuturo.com' AND p_pin = '931909' THEN 'VALLADOLID'
    WHEN p_email = 'delegacion_sevilla@nuevofuturo.com' AND p_pin = '129198' THEN 'SEVILLA'
    WHEN p_email = 'delegacion_santander@nuevofuturo.com' AND p_pin = '280062' THEN 'SANTANDER'
    WHEN p_email = 'delegacion_madrid@nuevofuturo.com' AND p_pin = '228738' THEN 'MADRID'
    WHEN p_email = 'delegacion_concepcion@nuevofuturo.com' AND p_pin = '670959' THEN 'CONCEPCION'
    WHEN p_email = 'delegacion_alava@nuevofuturo.com' AND p_pin = '768381' THEN 'ALAVA'
    ELSE NULL
  END;
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