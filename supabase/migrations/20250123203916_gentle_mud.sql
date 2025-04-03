-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Employees can insert their own time entries" ON time_entries;
DROP POLICY IF EXISTS "Employees can view their own time entries" ON time_entries;

-- Create comprehensive policies for time_entries
CREATE POLICY "Users can view time entries"
  ON time_entries
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = employee_id OR  -- Employee can view their own entries
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_entries.employee_id
      AND ep.company_id = auth.uid()  -- Company can view their employees' entries
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = (
        SELECT company_id FROM employee_profiles ep
        WHERE ep.id = time_entries.employee_id
      )
    )  -- Supervisor can view entries from their company's employees
  );

CREATE POLICY "Users can insert time entries"
  ON time_entries
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = employee_id OR  -- Employee can insert their own entries
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_entries.employee_id
      AND ep.company_id = auth.uid()  -- Company can insert entries for their employees
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = (
        SELECT company_id FROM employee_profiles ep
        WHERE ep.id = time_entries.employee_id
      )
    )  -- Supervisor can insert entries for their company's employees
  );

CREATE POLICY "Users can update time entries"
  ON time_entries
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_entries.employee_id
      AND ep.company_id = auth.uid()  -- Company can update their employees' entries
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = (
        SELECT company_id FROM employee_profiles ep
        WHERE ep.id = time_entries.employee_id
      )
    )  -- Supervisor can update entries from their company's employees
  );

CREATE POLICY "Users can delete time entries"
  ON time_entries
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_entries.employee_id
      AND ep.company_id = auth.uid()  -- Company can delete their employees' entries
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = (
        SELECT company_id FROM employee_profiles ep
        WHERE ep.id = time_entries.employee_id
      )
    )  -- Supervisor can delete entries from their company's employees
  );