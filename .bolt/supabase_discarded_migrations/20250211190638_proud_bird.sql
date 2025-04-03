-- Drop existing policies
DROP POLICY IF EXISTS "supervisor_delegation_access_v2" ON employee_profiles;

-- Create new policy without auth checks
CREATE POLICY "supervisor_delegation_access_v3"
  ON employee_profiles
  FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Create function to get delegation employees without auth checks
CREATE OR REPLACE FUNCTION get_delegation_employees_v3(
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
  -- Return all active employees for the delegation
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

-- Grant execute permission to all users
GRANT EXECUTE ON FUNCTION get_delegation_employees_v3(delegation_enum) TO anon;
GRANT EXECUTE ON FUNCTION get_delegation_employees_v3(delegation_enum) TO authenticated;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation_active 
ON employee_profiles(delegation, is_active);