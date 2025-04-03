-- Enable email confirmations and password recovery
ALTER TABLE auth.users
ENABLE ROW LEVEL SECURITY;

-- Create policy to allow password recovery
CREATE POLICY "Allow password recovery"
ON auth.users
FOR SELECT
TO anon
USING (true);

-- Create policy to allow email updates
CREATE POLICY "Allow email updates"
ON auth.users
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Create function to handle password recovery
CREATE OR REPLACE FUNCTION handle_password_recovery()
RETURNS TRIGGER AS $$
BEGIN
  -- Send password reset email
  PERFORM auth.send_reset_password_email(NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for password recovery
DROP TRIGGER IF EXISTS handle_password_recovery_trigger ON auth.users;
CREATE TRIGGER handle_password_recovery_trigger
  AFTER UPDATE OF recovery_token ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_password_recovery();

-- Add policy for employee_profiles to allow password recovery
CREATE POLICY "Allow password recovery for employees"
ON employee_profiles
FOR SELECT
TO anon
USING (
  email = current_setting('request.jwt.claims')::json->>'email'
  AND is_active = true
);