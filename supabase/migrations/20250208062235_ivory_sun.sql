-- Drop existing policies first to avoid conflicts
DROP POLICY IF EXISTS "supervisor_center_employee_access_v2" ON employee_profiles;
DROP POLICY IF EXISTS "supervisor_center_time_entries_v2" ON time_entries;
DROP POLICY IF EXISTS "supervisor_center_planner_requests_v2" ON planner_requests;
DROP POLICY IF EXISTS "supervisor_center_time_requests_v2" ON time_requests;
DROP POLICY IF EXISTS "supervisor_center_calendar_events_v2" ON calendar_events;
DROP POLICY IF EXISTS "supervisor_center_daily_work_hours_v2" ON daily_work_hours;

-- Create single comprehensive policy for supervisor center employee access
CREATE POLICY "supervisor_center_employee_access_v3"
  ON employee_profiles
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = employee_profiles.company_id
      AND sp.is_active = true
      AND sp.supervisor_type = 'center'
      AND employee_profiles.is_active = true
      AND employee_profiles.work_centers && sp.work_centers
    )
  );

-- Create single comprehensive policy for supervisor center time entries
CREATE POLICY "supervisor_center_time_entries_v3"
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
      AND sp.supervisor_type = 'center'
      AND ep.work_centers && sp.work_centers
    )
  );

-- Create function to get employees for a supervisor's work center
CREATE OR REPLACE FUNCTION get_supervisor_center_employees(p_supervisor_id UUID)
RETURNS TABLE (
  id UUID,
  fiscal_name TEXT,
  email TEXT,
  work_centers work_center_enum[],
  is_active BOOLEAN,
  document_type TEXT,
  document_number TEXT,
  created_at TIMESTAMPTZ,
  job_positions job_position_enum[],
  employee_id TEXT,
  seniority_date DATE,
  delegation delegation_enum
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ep.id,
    ep.fiscal_name,
    ep.email,
    ep.work_centers,
    ep.is_active,
    ep.document_type,
    ep.document_number,
    ep.created_at,
    ep.job_positions,
    ep.employee_id,
    ep.seniority_date,
    ep.delegation
  FROM employee_profiles ep
  JOIN supervisor_profiles sp ON sp.company_id = ep.company_id
  WHERE sp.id = p_supervisor_id
  AND sp.is_active = true
  AND ep.is_active = true
  AND sp.supervisor_type = 'center'
  AND ep.work_centers && sp.work_centers;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get time entries for a supervisor's work center
CREATE OR REPLACE FUNCTION get_supervisor_center_time_entries(p_supervisor_id UUID)
RETURNS TABLE (
  entry_id UUID,
  emp_id UUID,
  type_of_entry TEXT,
  entry_time TIMESTAMPTZ,
  type_of_time TEXT,
  center work_center_enum
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    te.id,
    te.employee_id,
    te.entry_type,
    te.timestamp,
    te.time_type,
    te.work_center
  FROM time_entries te
  JOIN employee_profiles ep ON ep.id = te.employee_id
  JOIN supervisor_profiles sp ON sp.company_id = ep.company_id
  WHERE sp.id = p_supervisor_id
  AND sp.is_active = true
  AND ep.is_active = true
  AND sp.supervisor_type = 'center'
  AND ep.work_centers && sp.work_centers;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers ON employee_profiles USING gin(work_centers);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_is_active ON employee_profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_work_centers ON supervisor_profiles USING gin(work_centers);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_type ON supervisor_profiles(supervisor_type);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_is_active ON supervisor_profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_company_id ON supervisor_profiles(company_id);
CREATE INDEX IF NOT EXISTS idx_time_entries_employee_id ON time_entries(employee_id);
CREATE INDEX IF NOT EXISTS idx_time_entries_work_center ON time_entries(work_center);