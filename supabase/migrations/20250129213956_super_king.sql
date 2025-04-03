-- Add work_center column to time_entries table
ALTER TABLE time_entries
ADD COLUMN IF NOT EXISTS work_center work_center_enum;

-- Create index for work_center
CREATE INDEX IF NOT EXISTS time_entries_work_center_idx ON time_entries(work_center);

-- Create trigger function to validate work center
CREATE OR REPLACE FUNCTION validate_time_entry_work_center()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if work_center exists in employee's work_centers
  IF NOT EXISTS (
    SELECT 1
    FROM employee_profiles
    WHERE id = NEW.employee_id
    AND NEW.work_center = ANY(work_centers)
  ) THEN
    RAISE EXCEPTION 'Invalid work center for employee';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to validate work center on insert and update
DROP TRIGGER IF EXISTS validate_time_entry_work_center_trigger ON time_entries;
CREATE TRIGGER validate_time_entry_work_center_trigger
  BEFORE INSERT OR UPDATE ON time_entries
  FOR EACH ROW
  EXECUTE FUNCTION validate_time_entry_work_center();