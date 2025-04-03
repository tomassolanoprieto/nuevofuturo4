-- Drop existing policies if they exist
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "time_requests_access" ON time_requests;
    DROP POLICY IF EXISTS "planner_requests_access" ON planner_requests;
EXCEPTION
    WHEN undefined_object THEN null;
END $$;

-- Create comprehensive policies for requests
CREATE POLICY "time_requests_access"
  ON time_requests
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "planner_requests_access"
  ON planner_requests
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create function to get employee work centers
CREATE OR REPLACE FUNCTION get_employee_work_centers(p_employee_id UUID)
RETURNS work_center_enum[] AS $$
  SELECT work_centers
  FROM employee_profiles
  WHERE id = p_employee_id;
$$ LANGUAGE sql SECURITY DEFINER;

-- Create function to validate employee work center
CREATE OR REPLACE FUNCTION validate_employee_work_center(p_employee_id UUID, p_work_center work_center_enum)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM employee_profiles
    WHERE id = p_employee_id
    AND p_work_center = ANY(work_centers)
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_time_requests_employee_id 
ON time_requests(employee_id);

CREATE INDEX IF NOT EXISTS idx_planner_requests_employee_id 
ON planner_requests(employee_id);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_company_id 
ON employee_profiles(company_id);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_company_id 
ON supervisor_profiles(company_id);