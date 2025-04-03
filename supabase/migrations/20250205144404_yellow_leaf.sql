-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view daily work hours" ON daily_work_hours;

-- Create comprehensive policies for daily_work_hours
CREATE POLICY "daily_work_hours_access"
  ON daily_work_hours
  FOR ALL
  TO authenticated
  USING (
    employee_id = auth.uid() OR  -- Employee can access their own records
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = daily_work_hours.employee_id
      AND ep.company_id = auth.uid()  -- Company can access their employees' records
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      JOIN employee_profiles ep ON ep.id = daily_work_hours.employee_id
      WHERE sp.id = auth.uid()
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )  -- Supervisor can access records from their employees
  )
  WITH CHECK (
    employee_id = auth.uid() OR  -- Employee can modify their own records
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = daily_work_hours.employee_id
      AND ep.company_id = auth.uid()  -- Company can modify their employees' records
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      JOIN employee_profiles ep ON ep.id = daily_work_hours.employee_id
      WHERE sp.id = auth.uid()
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )  -- Supervisor can modify records from their employees
  );

-- Create trigger function to handle automatic updates
CREATE OR REPLACE FUNCTION handle_daily_work_hours_updates()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic updates
DROP TRIGGER IF EXISTS daily_work_hours_update_trigger ON daily_work_hours;
CREATE TRIGGER daily_work_hours_update_trigger
  BEFORE UPDATE ON daily_work_hours
  FOR EACH ROW
  EXECUTE FUNCTION handle_daily_work_hours_updates();