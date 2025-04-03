-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS get_supervisor_center_employees_v5;
DROP FUNCTION IF EXISTS validate_supervisor_center_access;
DROP FUNCTION IF EXISTS get_supervisor_work_centers;

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
  v_supervisor_work_centers work_center_enum[];
BEGIN
  -- Get supervisor's work centers
  SELECT work_centers INTO v_supervisor_work_centers
  FROM supervisor_profiles
  WHERE email = p_email
  AND is_active = true
  AND supervisor_type = 'center';

  IF v_supervisor_work_centers IS NULL THEN
    RETURN;
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
  WHERE sp.email = p_email
  AND sp.is_active = true
  AND sp.supervisor_type = 'center'
  AND ep.is_active = true
  AND ep.work_centers && v_supervisor_work_centers
  ORDER BY ep.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create improved function to validate supervisor center access
CREATE OR REPLACE FUNCTION validate_supervisor_center_access(
  p_email TEXT,
  p_work_centers work_center_enum[]
)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM supervisor_profiles sp
    WHERE sp.email = p_email
    AND sp.is_active = true
    AND sp.supervisor_type = 'center'
    AND sp.work_centers && p_work_centers
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create improved function to get supervisor work centers
CREATE OR REPLACE FUNCTION get_supervisor_work_centers(
  p_email TEXT
)
RETURNS work_center_enum[] AS $$
DECLARE
  v_work_centers work_center_enum[];
BEGIN
  SELECT work_centers INTO v_work_centers
  FROM supervisor_profiles
  WHERE email = p_email
  AND is_active = true
  AND supervisor_type = 'center';

  RETURN v_work_centers;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create policy for supervisor center access
CREATE POLICY "supervisor_center_access_v2"
  ON supervisor_profiles
  FOR ALL
  TO authenticated
  USING (
    email = current_user OR
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE email = current_user
      AND raw_app_meta_data->>'role' = 'supervisor'
      AND raw_app_meta_data->>'supervisor_type' = 'center'
    )
  );

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_email_type 
ON supervisor_profiles(email, supervisor_type);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_work_centers_gin 
ON supervisor_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers_gin 
ON employee_profiles USING gin(work_centers);

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_supervisor_center_employees_v6 TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION validate_supervisor_center_access TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION get_supervisor_work_centers TO anon, PUBLIC;