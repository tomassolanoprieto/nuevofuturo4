-- Add work_center column to time_entries if it doesn't exist
ALTER TABLE time_entries
ADD COLUMN IF NOT EXISTS work_center work_center_enum;

-- Create index for work_center
CREATE INDEX IF NOT EXISTS idx_time_entries_work_center 
ON time_entries(work_center);

-- Create policy for time entries
CREATE POLICY "time_entries_access"
  ON time_entries
  FOR ALL
  TO anon, PUBLIC
  USING (true)
  WITH CHECK (true);

-- Enable RLS
ALTER TABLE time_entries ENABLE ROW LEVEL SECURITY;