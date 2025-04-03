-- Drop existing policies
DROP POLICY IF EXISTS "Companies can view their supervisors" ON supervisor_profiles;
DROP POLICY IF EXISTS "Companies can create supervisors" ON supervisor_profiles;
DROP POLICY IF EXISTS "Companies can update their supervisors" ON supervisor_profiles;
DROP POLICY IF EXISTS "Supervisors can view their own profile" ON supervisor_profiles;
DROP POLICY IF EXISTS "Supervisors can view company data" ON supervisor_profiles;

-- Create simplified policies
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

CREATE POLICY "Supervisors can view own profile"
  ON supervisor_profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());