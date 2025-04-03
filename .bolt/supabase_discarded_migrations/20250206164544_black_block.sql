-- Enable RLS for company_profiles
ALTER TABLE company_profiles ENABLE ROW LEVEL SECURITY;

-- Create policy to allow anonymous registration
CREATE POLICY "Allow anonymous registration"
  ON company_profiles
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- Create policy for authenticated users
CREATE POLICY "Allow authenticated access"
  ON company_profiles
  FOR ALL 
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());