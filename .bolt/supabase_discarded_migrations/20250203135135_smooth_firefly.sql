-- Drop existing trigger function for time entries
DROP TRIGGER IF EXISTS validate_time_entry_work_center_trigger ON time_entries;
DROP FUNCTION IF EXISTS validate_time_entry_work_center();

-- Create improved work center validation function
CREATE OR REPLACE FUNCTION validate_time_entry_work_center()
RETURNS TRIGGER AS $$
BEGIN
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

-- Add work_center column to time_entries if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'time_entries' 
    AND column_name = 'work_center'
  ) THEN
    ALTER TABLE time_entries
    ADD COLUMN work_center work_center_enum;
  END IF;
END $$;

-- Create index for work_center if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_time_entries_work_center 
ON time_entries(work_center);