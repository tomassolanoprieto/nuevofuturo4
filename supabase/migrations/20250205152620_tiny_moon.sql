-- Drop existing policies
DROP POLICY IF EXISTS "daily_work_hours_access" ON daily_work_hours;

-- Create separate policies for different operations
CREATE POLICY "daily_work_hours_select"
  ON daily_work_hours
  FOR SELECT
  TO authenticated
  USING (
    employee_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = daily_work_hours.employee_id
      AND ep.company_id = auth.uid()
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
    )
  );

CREATE POLICY "daily_work_hours_insert"
  ON daily_work_hours
  FOR INSERT
  TO authenticated
  WITH CHECK (true);  -- Allow all authenticated users to insert

CREATE POLICY "daily_work_hours_update"
  ON daily_work_hours
  FOR UPDATE
  TO authenticated
  USING (
    employee_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = daily_work_hours.employee_id
      AND ep.company_id = auth.uid()
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
    )
  );

-- Ensure the trigger function exists
CREATE OR REPLACE FUNCTION handle_daily_work_hours_updates()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
DROP TRIGGER IF EXISTS daily_work_hours_update_trigger ON daily_work_hours;
CREATE TRIGGER daily_work_hours_update_trigger
  BEFORE UPDATE ON daily_work_hours
  FOR EACH ROW
  EXECUTE FUNCTION handle_daily_work_hours_updates();