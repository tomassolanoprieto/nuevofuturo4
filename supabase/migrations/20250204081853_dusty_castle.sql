-- Add work_center column to time_entries if it doesn't exist
ALTER TABLE time_entries
ADD COLUMN IF NOT EXISTS work_center work_center_enum;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS validate_time_entry_work_center_trigger ON time_entries;
DROP FUNCTION IF EXISTS validate_time_entry_work_center();

-- Create improved validation function
CREATE OR REPLACE FUNCTION validate_time_entry_work_center()
RETURNS TRIGGER AS $$
BEGIN
  -- Only validate work_center if it's a clock_in entry
  IF NEW.entry_type = 'clock_in' AND NEW.work_center IS NULL THEN
    RAISE EXCEPTION 'Work center is required for clock-in entries';
  END IF;

  -- Only validate work_center if it's provided
  IF NEW.work_center IS NOT NULL THEN
    -- Check if work_center exists in employee's work_centers array
    IF NOT EXISTS (
      SELECT 1
      FROM employee_profiles
      WHERE id = NEW.employee_id
      AND NEW.work_center = ANY(work_centers)
    ) THEN
      RAISE EXCEPTION 'Invalid work center for employee';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for work center validation
CREATE TRIGGER validate_time_entry_work_center_trigger
  BEFORE INSERT OR UPDATE ON time_entries
  FOR EACH ROW
  EXECUTE FUNCTION validate_time_entry_work_center();

-- Create index for work_center if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_time_entries_work_center 
ON time_entries(work_center);

-- Create policy for time entries access
CREATE POLICY "time_entries_access"
  ON time_entries
  FOR ALL
  TO authenticated
  USING (
    employee_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_entries.employee_id
      AND ep.company_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      JOIN employee_profiles ep ON ep.id = time_entries.employee_id
      WHERE sp.id = auth.uid()
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  );