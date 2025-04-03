-- Drop existing policies
DROP POLICY IF EXISTS "supervisor_access_policy" ON supervisor_profiles;

-- Create comprehensive policies for supervisors similar to employees and companies
CREATE POLICY "Supervisors can view their own profile"
  ON supervisor_profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

CREATE POLICY "Companies can view their supervisors"
  ON supervisor_profiles
  FOR SELECT
  TO authenticated
  USING (company_id = auth.uid());

CREATE POLICY "Companies can create supervisors"
  ON supervisor_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (company_id = auth.uid());

CREATE POLICY "Companies can update their supervisors"
  ON supervisor_profiles
  FOR UPDATE
  TO authenticated
  USING (company_id = auth.uid());

-- Add policy for supervisors to access employee data
CREATE POLICY "Supervisors can view employee data"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = employee_profiles.company_id
      AND sp.is_active = true
      AND employee_profiles.work_center = ANY(sp.work_centers)
    )
  );