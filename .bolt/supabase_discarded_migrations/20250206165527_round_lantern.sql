-- Drop existing policies
DROP POLICY IF EXISTS "Allow company registration" ON company_profiles;
DROP POLICY IF EXISTS "Companies can access own profile" ON company_profiles;

-- Create improved policies for company registration
CREATE POLICY "Allow company registration"
  ON company_profiles
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Companies can access own profile"
  ON company_profiles
  FOR ALL
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Create function to confirm email automatically
CREATE OR REPLACE FUNCTION auto_confirm_email()
RETURNS TRIGGER AS $$
BEGIN
  -- Automatically confirm email for new users
  UPDATE auth.users
  SET email_confirmed_at = NOW(),
      confirmed_at = NOW()
  WHERE id = NEW.id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to confirm email
CREATE TRIGGER confirm_company_email
  AFTER INSERT ON company_profiles
  FOR EACH ROW
  EXECUTE FUNCTION auto_confirm_email();