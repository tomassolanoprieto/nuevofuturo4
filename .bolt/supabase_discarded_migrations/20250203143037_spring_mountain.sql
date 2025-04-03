-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view employee data" ON employee_profiles;
DROP POLICY IF EXISTS "Users can view own employee profile" ON employee_profiles;
DROP POLICY IF EXISTS "Users can update own employee profile" ON employee_profiles;
DROP POLICY IF EXISTS "Users can insert own employee profile" ON employee_profiles;

-- Create comprehensive policies for employee access
CREATE POLICY "Users can view employee data"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (
    id = auth.uid() OR  -- Employee can view their own data
    company_id = auth.uid() OR  -- Company can view their employees' data
    EXISTS (  -- Supervisor can view data based on their type
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = employee_profiles.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND employee_profiles.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND employee_profiles.delegation = ANY(sp.delegations))
      )
    )
  );

CREATE POLICY "Users can update employee data"
  ON employee_profiles
  FOR UPDATE
  TO authenticated
  USING (
    id = auth.uid() OR  -- Employee can update their own data
    company_id = auth.uid()  -- Company can update their employees' data
  );

CREATE POLICY "Users can insert employee data"
  ON employee_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    id = auth.uid() OR  -- Employee can insert their own data
    company_id = auth.uid()  -- Company can insert data for their employees
  );

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_company_id 
ON employee_profiles(company_id);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers 
ON employee_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation 
ON employee_profiles(delegation);

-- Enable row level security if not already enabled
ALTER TABLE employee_profiles ENABLE ROW LEVEL SECURITY;