-- Create function to get employees for supervisor center
CREATE OR REPLACE FUNCTION get_supervisor_center_employees_v4(
  p_supervisor_id UUID
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
  v_supervisor_work_centers work_center_enum[];
BEGIN
  -- Get supervisor's work centers
  SELECT work_centers INTO v_supervisor_work_centers
  FROM supervisor_profiles
  WHERE id = p_supervisor_id
  AND is_active = true
  AND supervisor_type = 'center';

  IF v_supervisor_work_centers IS NULL THEN
    RAISE EXCEPTION 'Supervisor de centro no encontrado o inactivo';
  END IF;

  -- Return employees that have any of the supervisor's work centers
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
  JOIN supervisor_profiles sp ON sp.company_id = ep.company_id
  WHERE sp.id = p_supervisor_id
  AND sp.is_active = true
  AND sp.supervisor_type = 'center'
  AND ep.is_active = true
  AND ep.work_centers && v_supervisor_work_centers
  ORDER BY ep.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get employees for supervisor delegation
CREATE OR REPLACE FUNCTION get_delegation_employees_v4(
  p_supervisor_id UUID
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
  v_supervisor_delegations delegation_enum[];
BEGIN
  -- Get supervisor's delegations
  SELECT delegations INTO v_supervisor_delegations
  FROM supervisor_profiles
  WHERE id = p_supervisor_id
  AND is_active = true
  AND supervisor_type = 'delegation';

  IF v_supervisor_delegations IS NULL THEN
    RAISE EXCEPTION 'Supervisor de delegación no encontrado o inactivo';
  END IF;

  -- Return employees that belong to any of the supervisor's delegations
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
  JOIN supervisor_profiles sp ON sp.company_id = ep.company_id
  WHERE sp.id = p_supervisor_id
  AND sp.is_active = true
  AND sp.supervisor_type = 'delegation'
  AND ep.is_active = true
  AND ep.delegation = ANY(v_supervisor_delegations)
  ORDER BY ep.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to validate employee access for supervisor
CREATE OR REPLACE FUNCTION validate_supervisor_employee_access_v2(
  p_supervisor_id UUID,
  p_employee_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_supervisor_type TEXT;
  v_supervisor_work_centers work_center_enum[];
  v_supervisor_delegations delegation_enum[];
BEGIN
  -- Get supervisor info
  SELECT 
    supervisor_type,
    work_centers,
    delegations
  INTO 
    v_supervisor_type,
    v_supervisor_work_centers,
    v_supervisor_delegations
  FROM supervisor_profiles
  WHERE id = p_supervisor_id
  AND is_active = true;

  IF v_supervisor_type IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Check access based on supervisor type
  RETURN EXISTS (
    SELECT 1 
    FROM employee_profiles ep
    WHERE ep.id = p_employee_id
    AND ep.is_active = true
    AND (
      (v_supervisor_type = 'center' AND ep.work_centers && v_supervisor_work_centers) OR
      (v_supervisor_type = 'delegation' AND ep.delegation = ANY(v_supervisor_delegations))
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create policy for employee data access
CREATE POLICY "supervisor_employee_access_v4"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = employee_profiles.company_id
      AND sp.is_active = true
      AND employee_profiles.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND employee_profiles.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND employee_profiles.delegation = ANY(sp.delegations))
      )
    )
  );

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers_gin 
ON employee_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation_btree 
ON employee_profiles(delegation);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_work_centers_gin 
ON supervisor_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_delegations_gin 
ON supervisor_profiles USING gin(delegations);

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_supervisor_center_employees_v4 TO authenticated;
GRANT EXECUTE ON FUNCTION get_delegation_employees_v4 TO authenticated;
GRANT EXECUTE ON FUNCTION validate_supervisor_employee_access_v2 TO authenticated;