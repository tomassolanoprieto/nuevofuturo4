-- Drop existing policies first to avoid conflicts
DROP POLICY IF EXISTS "supervisor_center_data_access" ON employee_profiles;
DROP POLICY IF EXISTS "supervisor_center_time_entries_access" ON time_entries;
DROP POLICY IF EXISTS "supervisor_center_planner_access" ON planner_requests;
DROP POLICY IF EXISTS "supervisor_center_time_requests_access" ON time_requests;
DROP POLICY IF EXISTS "supervisor_center_calendar_access" ON calendar_events;
DROP POLICY IF EXISTS "supervisor_center_daily_hours_access" ON daily_work_hours;

-- Create improved policy for supervisor center employee access
CREATE POLICY "supervisor_center_employee_access_v2"
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

-- Create improved policy for supervisor center time entries
CREATE POLICY "supervisor_center_time_entries_v2"
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

-- Create improved policy for supervisor center planner requests
CREATE POLICY "supervisor_center_planner_requests_v2"
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
      AND sp.supervisor_type = 'center'
      AND ep.work_centers && sp.work_centers
    )
  );

-- Create improved policy for supervisor center time requests
CREATE POLICY "supervisor_center_time_requests_v2"
  ON time_requests
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      JOIN employee_profiles ep ON ep.id = time_requests.employee_id
      WHERE sp.id = auth.uid()
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND ep.is_active = true
      AND sp.supervisor_type = 'center'
      AND ep.work_centers && sp.work_centers
    )
  );

-- Create improved policy for supervisor center calendar events
CREATE POLICY "supervisor_center_calendar_events_v2"
  ON calendar_events
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      JOIN employee_profiles ep ON ep.id = calendar_events.employee_id
      WHERE sp.id = auth.uid()
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND ep.is_active = true
      AND sp.supervisor_type = 'center'
      AND ep.work_centers && sp.work_centers
    )
  );

-- Create improved policy for supervisor center daily work hours
CREATE POLICY "supervisor_center_daily_work_hours_v2"
  ON daily_work_hours
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      JOIN employee_profiles ep ON ep.id = daily_work_hours.employee_id
      WHERE sp.id = auth.uid()
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND ep.is_active = true
      AND sp.supervisor_type = 'center'
      AND ep.work_centers && sp.work_centers
    )
  );

-- Create function to get supervisor's work center
CREATE OR REPLACE FUNCTION get_supervisor_work_center(p_supervisor_id UUID)
RETURNS work_center_enum[] AS $$
BEGIN
  RETURN (
    SELECT work_centers
    FROM supervisor_profiles
    WHERE id = p_supervisor_id
    AND is_active = true
    AND supervisor_type = 'center'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if employee belongs to supervisor's work center
CREATE OR REPLACE FUNCTION is_employee_in_supervisor_center(p_employee_id UUID, p_supervisor_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM supervisor_profiles sp
    JOIN employee_profiles ep ON ep.work_centers && sp.work_centers
    WHERE sp.id = p_supervisor_id
    AND ep.id = p_employee_id
    AND sp.is_active = true
    AND ep.is_active = true
    AND sp.supervisor_type = 'center'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers ON employee_profiles USING gin(work_centers);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_work_centers ON supervisor_profiles USING gin(work_centers);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_type ON supervisor_profiles(supervisor_type);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_active ON supervisor_profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_active ON employee_profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_time_entries_employee_id ON time_entries(employee_id);
CREATE INDEX IF NOT EXISTS idx_planner_requests_employee_id ON planner_requests(employee_id);
CREATE INDEX IF NOT EXISTS idx_time_requests_employee_id ON time_requests(employee_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_employee_id ON calendar_events(employee_id);
CREATE INDEX IF NOT EXISTS idx_daily_work_hours_employee_id ON daily_work_hours(employee_id);