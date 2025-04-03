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
      AND employee_profiles.delegation = ANY(sp.delegations)
    )
  );

-- Create function to get delegation employees
CREATE OR REPLACE FUNCTION get_delegation_employees(p_delegation delegation_enum)
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
  WHERE ep.delegation = p_delegation
  AND ep.is_active = true
  ORDER BY ep.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_delegation_employees(delegation_enum) TO authenticated;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation_active 
ON employee_profiles(delegation, is_active);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_delegations 
ON supervisor_profiles USING gin(delegations);