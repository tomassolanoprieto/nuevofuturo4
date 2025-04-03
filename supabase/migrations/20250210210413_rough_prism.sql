-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view time entries" ON time_entries;
DROP POLICY IF EXISTS "Users can insert time entries" ON time_entries;
DROP POLICY IF EXISTS "Users can update time entries" ON time_entries;
DROP POLICY IF EXISTS "Users can delete time entries" ON time_entries;
DROP POLICY IF EXISTS "time_entries_access" ON time_entries;
DROP POLICY IF EXISTS "time_entries_access_v2" ON time_entries;
DROP POLICY IF EXISTS "time_entries_access_v3" ON time_entries;

-- Create simplified policy for time entries
CREATE POLICY "time_entries_access_v4"
  ON time_entries
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create function to get employee ID from JWT claims
CREATE OR REPLACE FUNCTION get_employee_id_from_jwt()
RETURNS UUID AS $$
BEGIN
  RETURN (current_setting('request.jwt.claims')::json->>'sub')::UUID;
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
    AND (
      -- Employee accessing their own entries
      ep.id = auth.uid() OR
      -- Company accessing their employees' entries
      ep.company_id = auth.uid()
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_time_entries_employee_id 
ON time_entries(employee_id);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_company_id 
ON employee_profiles(company_id);