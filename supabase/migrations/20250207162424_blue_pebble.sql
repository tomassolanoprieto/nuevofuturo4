-- Drop existing policies first
DROP POLICY IF EXISTS "supervisor_profiles_access" ON supervisor_profiles;
DROP POLICY IF EXISTS "supervisor_employee_access" ON employee_profiles;

-- Create comprehensive policies for supervisor access
CREATE POLICY "supervisor_base_access"
  ON supervisor_profiles
  FOR ALL
  TO authenticated
  USING (
    id = auth.uid() OR 
    company_id = auth.uid()
  )
  WITH CHECK (company_id = auth.uid());

-- Policy for supervisors to view employee data
CREATE POLICY "supervisor_employee_access"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
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

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_company_id ON supervisor_profiles(company_id);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_is_active ON supervisor_profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_work_centers ON supervisor_profiles USING gin(work_centers);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_delegations ON supervisor_profiles USING gin(delegations);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_supervisor_type ON supervisor_profiles(supervisor_type);