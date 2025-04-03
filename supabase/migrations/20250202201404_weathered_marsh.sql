-- Drop existing policies
DROP POLICY IF EXISTS "supervisor_base_access" ON supervisor_profiles;
DROP POLICY IF EXISTS "supervisor_employee_access" ON employee_profiles;

-- Create simplified policies for supervisor access
CREATE POLICY "anon_supervisor_auth"
  ON supervisor_profiles
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Create policy for basic supervisor data access
CREATE POLICY "supervisor_data_access"
  ON supervisor_profiles
  FOR SELECT
  TO authenticated
  USING (
    id = auth.uid() OR 
    company_id = auth.uid()
  );

-- Create index for faster supervisor lookups
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_email_pin 
ON supervisor_profiles(email, pin);

-- Create index for supervisor type lookups
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_type 
ON supervisor_profiles(supervisor_type);