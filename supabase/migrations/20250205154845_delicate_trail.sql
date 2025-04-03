-- Drop existing policies
DROP POLICY IF EXISTS "daily_work_hours_select" ON daily_work_hours;
DROP POLICY IF EXISTS "daily_work_hours_insert" ON daily_work_hours;
DROP POLICY IF EXISTS "daily_work_hours_update" ON daily_work_hours;

-- Create simplified policy for daily_work_hours
CREATE POLICY "daily_work_hours_access"
  ON daily_work_hours
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

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

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_daily_work_hours_employee_date 
ON daily_work_hours(employee_id, work_date);

CREATE INDEX IF NOT EXISTS idx_daily_work_hours_hours_by_type 
ON daily_work_hours USING gin(hours_by_type);

CREATE INDEX IF NOT EXISTS idx_daily_work_hours_hours_by_center 
ON daily_work_hours USING gin(hours_by_center);