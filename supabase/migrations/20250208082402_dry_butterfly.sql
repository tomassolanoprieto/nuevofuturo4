-- Drop existing policies first to avoid conflicts
DROP POLICY IF EXISTS "supervisor_access_policy_v3" ON supervisor_profiles;
DROP POLICY IF EXISTS "supervisor_employee_access_policy_v3" ON employee_profiles;

-- Create policy for supervisor access
CREATE POLICY "supervisor_delegation_access"
  ON supervisor_profiles
  FOR ALL
  TO authenticated
  USING (
    id = auth.uid() OR 
    company_id = auth.uid()
  )
  WITH CHECK (company_id = auth.uid());

-- Create policy for supervisor delegation access to employee data
CREATE POLICY "supervisor_delegation_employee_access"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = employee_profiles.company_id
      AND sp.is_active = true
      AND sp.supervisor_type = 'delegation'
      AND employee_profiles.is_active = true
      AND employee_profiles.delegation = ANY(sp.delegations)
    )
  );

-- Create function to get delegation employees
CREATE OR REPLACE FUNCTION get_delegation_employees_v2(p_supervisor_id UUID)
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

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation 
ON employee_profiles(delegation);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_is_active 
ON employee_profiles(is_active);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_delegations 
ON supervisor_profiles USING gin(delegations);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_type 
ON supervisor_profiles(supervisor_type);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_is_active 
ON supervisor_profiles(is_active);