-- Drop existing policies first to avoid conflicts
DROP POLICY IF EXISTS "supervisor_access_policy" ON supervisor_profiles;
DROP POLICY IF EXISTS "supervisor_employee_access_policy" ON employee_profiles;

-- Create comprehensive policy for supervisor access
CREATE POLICY "supervisor_access_policy_v2"
  ON supervisor_profiles
  FOR ALL
  TO authenticated
  USING (
    id = auth.uid() OR 
    company_id = auth.uid()
  )
  WITH CHECK (company_id = auth.uid());

-- Create policy for supervisor access to employee data
CREATE POLICY "supervisor_employee_access_policy_v2"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = employee_profiles.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND employee_profiles.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND employee_profiles.delegation = ANY(sp.delegations))
      )
    )
  );

-- Create function to authenticate supervisor
CREATE OR REPLACE FUNCTION authenticate_supervisor(
  p_email TEXT,
  p_pin TEXT
)
RETURNS TABLE (
  id UUID,
  email TEXT,
  supervisor_type TEXT,
  work_centers work_center_enum[],
  delegations delegation_enum[],
  company_id UUID
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sp.id,
    sp.email,
    sp.supervisor_type::TEXT,
    sp.work_centers,
    sp.delegations,
    sp.company_id
  FROM supervisor_profiles sp
  WHERE sp.email = p_email 
  AND sp.pin = p_pin
  AND sp.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get delegation employees
CREATE OR REPLACE FUNCTION get_delegation_employees(p_supervisor_id UUID)
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
  is_active BOOLEAN
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
    ep.is_active
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
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_email_pin 
ON supervisor_profiles(email, pin);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_type_active 
ON supervisor_profiles(supervisor_type, is_active);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation_active 
ON employee_profiles(delegation, is_active);