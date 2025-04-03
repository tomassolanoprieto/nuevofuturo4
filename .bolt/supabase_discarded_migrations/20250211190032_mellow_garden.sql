-- Drop existing policies if they exist
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "supervisor_delegation_employee_access" ON employee_profiles;
    DROP POLICY IF EXISTS "supervisor_delegation_data_access" ON employee_profiles;
EXCEPTION
    WHEN undefined_object THEN null;
END $$;

-- Create improved policy for supervisor delegation access
CREATE POLICY "supervisor_delegation_access_v2"
  ON employee_profiles
  FOR ALL
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

-- Create function to get delegation employees with better error handling
CREATE OR REPLACE FUNCTION get_delegation_employees_v2(
  p_supervisor_id UUID,
  p_delegation delegation_enum DEFAULT NULL
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
  -- Validate supervisor exists and is active
  IF NOT EXISTS (
    SELECT 1 FROM supervisor_profiles
    WHERE id = p_supervisor_id
    AND is_active = true
    AND supervisor_type = 'delegation'
  ) THEN
    RAISE EXCEPTION 'Supervisor no encontrado o inactivo';
  END IF;

  -- Return employees for the delegation
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
  AND (
    p_delegation IS NULL OR 
    ep.delegation = p_delegation
  )
  AND ep.delegation = ANY(sp.delegations)
  ORDER BY ep.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_delegation_employees_v2(UUID, delegation_enum) TO authenticated;

-- Create or replace indexes for better performance
DROP INDEX IF EXISTS idx_employee_profiles_delegation_active;
DROP INDEX IF EXISTS idx_supervisor_profiles_delegations;
DROP INDEX IF EXISTS idx_supervisor_profiles_type_active;

CREATE INDEX idx_employee_profiles_delegation_active 
ON employee_profiles(delegation, is_active);

CREATE INDEX idx_supervisor_profiles_delegations 
ON supervisor_profiles USING gin(delegations);

CREATE INDEX idx_supervisor_profiles_type_active 
ON supervisor_profiles(supervisor_type, is_active);