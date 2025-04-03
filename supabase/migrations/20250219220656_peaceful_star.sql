-- Create function to get employees by work centers
CREATE OR REPLACE FUNCTION get_employees_by_work_centers(
  p_work_centers work_center_enum[]
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
  WHERE ep.work_centers && p_work_centers
  AND ep.is_active = true
  ORDER BY ep.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to validate supervisor center access
CREATE OR REPLACE FUNCTION validate_supervisor_center_access(
  p_supervisor_id UUID,
  p_work_centers work_center_enum[]
)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM supervisor_profiles sp
    WHERE sp.id = p_supervisor_id
    AND sp.is_active = true
    AND sp.supervisor_type = 'center'
    AND sp.work_centers && p_work_centers
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get supervisor work centers
CREATE OR REPLACE FUNCTION get_supervisor_work_centers(
  p_supervisor_id UUID
)
RETURNS work_center_enum[] AS $$
DECLARE
  v_work_centers work_center_enum[];
BEGIN
  SELECT work_centers INTO v_work_centers
  FROM supervisor_profiles
  WHERE id = p_supervisor_id
  AND is_active = true
  AND supervisor_type = 'center';

  RETURN v_work_centers;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers_gin 
ON employee_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_work_centers_gin 
ON supervisor_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_type 
ON supervisor_profiles(supervisor_type);

CREATE INDEX IF NOT EXISTS idx_time_entries_employee_id 
ON time_entries(employee_id);

CREATE INDEX IF NOT EXISTS idx_planner_requests_employee_id 
ON planner_requests(employee_id);

CREATE INDEX IF NOT EXISTS idx_time_requests_employee_id 
ON time_requests(employee_id);

CREATE INDEX IF NOT EXISTS idx_calendar_events_employee_id 
ON calendar_events(employee_id);

CREATE INDEX IF NOT EXISTS idx_daily_work_hours_employee_id 
ON daily_work_hours(employee_id);

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_employees_by_work_centers TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION validate_supervisor_center_access TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION get_supervisor_work_centers TO anon, PUBLIC;