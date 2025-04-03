-- Drop existing policies if they exist
DROP POLICY IF EXISTS "supervisor_employee_access" ON employee_profiles;

-- Create comprehensive policy for employee access
CREATE POLICY "employee_access_policy"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (
    id = auth.uid() OR  -- Employee can view their own profile
    company_id = auth.uid() OR  -- Company can view all their employees
    EXISTS (  -- Supervisor can view employees based on their type and assignments
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

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_company_id ON employee_profiles(company_id);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers ON employee_profiles USING gin(work_centers);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation ON employee_profiles(delegation);