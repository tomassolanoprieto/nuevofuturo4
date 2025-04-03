-- Create function to get employees for supervisor center
CREATE OR REPLACE FUNCTION get_supervisor_center_employees_v3(
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
  JOIN supervisor_profiles sp ON sp.company_id = ep.company_id
  WHERE sp.id = p_supervisor_id
  AND sp.is_active = true
  AND sp.supervisor_type = 'center'
  AND ep.is_active = true
  AND ep.work_centers && sp.work_centers
  ORDER BY ep.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get employees for supervisor delegation
CREATE OR REPLACE FUNCTION get_delegation_employees_v3(
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
  JOIN supervisor_profiles sp ON sp.company_id = ep.company_id
  WHERE sp.id = p_supervisor_id
  AND sp.is_active = true
  AND sp.supervisor_type = 'delegation'
  AND ep.is_active = true
  AND ep.delegation = ANY(sp.delegations)
  ORDER BY ep.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to validate employee access for supervisor
CREATE OR REPLACE FUNCTION validate_supervisor_employee_access(
  p_supervisor_id UUID,
  p_employee_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM supervisor_profiles sp
    JOIN employee_profiles ep ON ep.company_id = sp.company_id
    WHERE sp.id = p_supervisor_id
    AND ep.id = p_employee_id
    AND sp.is_active = true
    AND ep.is_active = true
    AND (
      (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
      (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create policy for supervisor access to employee data
CREATE POLICY "supervisor_employee_access_v3"
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

-- Create policy for supervisor access to time entries
CREATE POLICY "supervisor_time_entries_access_v3"
  ON time_entries
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      JOIN employee_profiles ep ON ep.id = time_entries.employee_id
      WHERE sp.id = auth.uid()
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND ep.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  );

-- Create policy for supervisor access to requests
CREATE POLICY "supervisor_requests_access_v3"
  ON planner_requests
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      JOIN employee_profiles ep ON ep.id = planner_requests.employee_id
      WHERE sp.id = auth.uid()
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND ep.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  );

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_supervisor_center_employees_v3 TO authenticated;
GRANT EXECUTE ON FUNCTION get_delegation_employees_v3 TO authenticated;
GRANT EXECUTE ON FUNCTION validate_supervisor_employee_access TO authenticated;