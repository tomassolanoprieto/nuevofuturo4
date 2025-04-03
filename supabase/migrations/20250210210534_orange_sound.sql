-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view time entries" ON time_entries;
DROP POLICY IF EXISTS "Users can insert time entries" ON time_entries;
DROP POLICY IF EXISTS "Users can update time entries" ON time_entries;
DROP POLICY IF EXISTS "Users can delete time entries" ON time_entries;
DROP POLICY IF EXISTS "time_entries_access" ON time_entries;
DROP POLICY IF EXISTS "time_entries_access_v2" ON time_entries;
DROP POLICY IF EXISTS "time_entries_access_v3" ON time_entries;
DROP POLICY IF EXISTS "time_entries_access_v4" ON time_entries;

-- Create function to get employee ID from localStorage
CREATE OR REPLACE FUNCTION get_stored_employee_id()
RETURNS UUID AS $$
BEGIN
  -- Try to get employee ID from localStorage
  RETURN current_setting('request.headers')::jsonb->>'employeeId';
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if user can access time entry
CREATE OR REPLACE FUNCTION can_access_time_entry(p_employee_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM employee_profiles ep
    WHERE ep.id = p_employee_id
    AND ep.is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create policy for time entries access
CREATE POLICY "time_entries_access_v5"
  ON time_entries
  FOR ALL
  TO authenticated
  USING (
    -- Employee can access their own entries
    employee_id = get_stored_employee_id() OR
    -- Company can access their employees' entries
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_entries.employee_id
      AND ep.company_id = auth.uid()
    )
  )
  WITH CHECK (
    -- Employee can modify their own entries
    employee_id = get_stored_employee_id() OR
    -- Company can modify their employees' entries
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_entries.employee_id
      AND ep.company_id = auth.uid()
    )
  );

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_time_entries_employee_id 
ON time_entries(employee_id);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_company_id 
ON employee_profiles(company_id);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_is_active 
ON employee_profiles(is_active);