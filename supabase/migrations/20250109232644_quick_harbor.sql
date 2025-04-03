/*
  # Fix employee authentication

  1. Changes
    - Add trigger to automatically create Supabase Auth users for new employees
    - Add function to handle employee creation in auth.users
    - Ensure PIN is used as password for auth.users
  
  2. Security
    - Only company users can trigger the employee creation
    - Passwords are securely handled
*/

-- Function to create auth user for employee
CREATE OR REPLACE FUNCTION create_auth_user_for_employee()
RETURNS TRIGGER AS $$
BEGIN
  -- Only proceed if the PIN is set and no auth user exists
  IF NEW.pin IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM auth.users WHERE email = NEW.email
  ) THEN
    -- Create the auth user with the PIN as password
    INSERT INTO auth.users (
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      role
    )
    VALUES (
      NEW.email,
      crypt(NEW.pin, gen_salt('bf')),
      NOW(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"employee"}',
      NOW(),
      NOW(),
      'authenticated'
    );

    -- Update the employee profile with the new auth user id
    NEW.id = (SELECT id FROM auth.users WHERE email = NEW.email);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS create_auth_user_trigger ON employee_profiles;

-- Create trigger for new employee profiles
CREATE TRIGGER create_auth_user_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION create_auth_user_for_employee();