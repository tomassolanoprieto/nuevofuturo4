-- Create policy for supervisor center data access
CREATE POLICY "supervisor_center_data_access"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = employee_profiles.company_id
      AND sp.is_active = true
      AND sp.supervisor_type = 'center'
      AND employee_profiles.work_centers && sp.work_centers
    )
  );

-- Create policy for supervisor center time entries access
CREATE POLICY "supervisor_center_time_entries_access"
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
      AND sp.supervisor_type = 'center'
      AND ep.work_centers && sp.work_centers
    )
  );

-- Create policy for supervisor center planner requests access
CREATE POLICY "supervisor_center_planner_access"
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
      AND sp.supervisor_type = 'center'
      AND ep.work_centers && sp.work_centers
    )
  );

-- Create policy for supervisor center time requests access
CREATE POLICY "supervisor_center_time_requests_access"
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
      AND sp.supervisor_type = 'center'
      AND ep.work_centers && sp.work_centers
    )
  );

-- Create policy for supervisor center calendar events access
CREATE POLICY "supervisor_center_calendar_access"
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
      AND sp.supervisor_type = 'center'
      AND ep.work_centers && sp.work_centers
    )
  );

-- Create policy for supervisor center daily work hours access
CREATE POLICY "supervisor_center_daily_hours_access"
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
      AND sp.supervisor_type = 'center'
      AND ep.work_centers && sp.work_centers
    )
  );

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers ON employee_profiles USING gin(work_centers);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_work_centers ON supervisor_profiles USING gin(work_centers);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_type ON supervisor_profiles(supervisor_type);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_active ON supervisor_profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_time_entries_employee_id ON time_entries(employee_id);
CREATE INDEX IF NOT EXISTS idx_planner_requests_employee_id ON planner_requests(employee_id);
CREATE INDEX IF NOT EXISTS idx_time_requests_employee_id ON time_requests(employee_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_employee_id ON calendar_events(employee_id);
CREATE INDEX IF NOT EXISTS idx_daily_work_hours_employee_id ON daily_work_hours(employee_id);