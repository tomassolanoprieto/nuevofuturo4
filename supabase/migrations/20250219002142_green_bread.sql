-- Add work_center column to holidays if it doesn't exist
ALTER TABLE holidays
ADD COLUMN IF NOT EXISTS work_center work_center_enum;

-- Create index for work_center in holidays
CREATE INDEX IF NOT EXISTS idx_holidays_work_center 
ON holidays(work_center);

-- Add foreign key to planner_requests if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'planner_requests_employee_id_fkey'
    ) THEN
        ALTER TABLE planner_requests
        ADD CONSTRAINT planner_requests_employee_id_fkey 
        FOREIGN KEY (employee_id) 
        REFERENCES employee_profiles(id)
        ON DELETE CASCADE;
    END IF;
END $$;

-- Create index for employee_id in planner_requests
CREATE INDEX IF NOT EXISTS idx_planner_requests_employee_id 
ON planner_requests(employee_id);

-- Drop existing policies if they exist
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "holidays_access" ON holidays;
    DROP POLICY IF EXISTS "planner_requests_access" ON planner_requests;
EXCEPTION
    WHEN undefined_object THEN null;
END $$;

-- Create policy for holidays access
CREATE POLICY "holidays_access"
  ON holidays
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create policy for planner requests access
CREATE POLICY "planner_requests_access"
  ON planner_requests
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Enable RLS
ALTER TABLE holidays ENABLE ROW LEVEL SECURITY;
ALTER TABLE planner_requests ENABLE ROW LEVEL SECURITY;