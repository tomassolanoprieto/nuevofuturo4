-- Drop existing trigger and function
DROP TRIGGER IF EXISTS validate_time_entry_work_center_trigger ON time_entries;
DROP FUNCTION IF EXISTS validate_time_entry_work_center();

-- Create improved validation function
CREATE OR REPLACE FUNCTION validate_time_entry_work_center()
RETURNS TRIGGER AS $$
BEGIN
  -- Only validate work_center for clock_in entries
  IF NEW.entry_type = 'clock_in' THEN
    -- Check if work_center is provided
    IF NEW.work_center IS NULL THEN
      RAISE EXCEPTION 'Work center is required for clock-in entries';
    END IF;

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