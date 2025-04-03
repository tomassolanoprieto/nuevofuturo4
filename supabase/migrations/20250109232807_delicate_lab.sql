/*
  # Fix employee authentication final

  1. Changes
    - Add PIN column if not exists
    - Create function to handle employee auth
    - Add trigger for employee creation
    - Update existing employees
  
  2. Security
    - Maintain RLS policies
    - Ensure secure password handling
    - Validate PIN format
*/

-- Ensure PIN column exists with proper constraint
ALTER TABLE employee_profiles
DROP CONSTRAINT IF EXISTS pin_format;

ALTER TABLE employee_profiles
ADD COLUMN IF NOT EXISTS pin TEXT;

ALTER TABLE employee_profiles
ADD CONSTRAINT pin_format CHECK (pin ~ '^\d{6}$');

-- Create or replace the auth handling function
CREATE OR REPLACE FUNCTION handle_employee_auth()
RETURNS TRIGGER AS $$
BEGIN
  -- Ensure PIN is set
  IF NEW.pin IS NULL THEN
    RAISE EXCEPTION 'PIN is required';
  END IF;

  -- Ensure PIN is exactly 6 digits
  IF NEW.pin !~ '^\d{6}$' THEN
    RAISE EXCEPTION 'PIN must be exactly 6 digits';
  END IF;

  -- Check if auth user already exists
  IF EXISTS (
    SELECT 1 FROM auth.users WHERE email = NEW.email
  ) THEN
    -- Update existing auth user's password
    UPDATE auth.users 
    SET encrypted_password = crypt(NEW.pin, gen_salt('bf')),
        raw_app_meta_data = jsonb_set(
          COALESCE(raw_app_meta_data, '{}'::jsonb),
          '{role}',
          '"employee"'
        ),
        updated_at = NOW()
    WHERE email = NEW.email;
    
    -- Get the existing user's ID
    SELECT id INTO NEW.id
    FROM auth.users
    WHERE email = NEW.email;
  ELSE
    -- Create new auth user
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
      '{"provider":"email","providers":["email"],"role":"employee"}'::jsonb,
      '{}'::jsonb,
      NOW(),
      NOW(),
      'authenticated'
    )
    RETURNING id INTO NEW.id;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN others THEN
    RAISE EXCEPTION 'Error creating employee: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS handle_employee_auth_trigger ON employee_profiles;

-- Create new trigger
CREATE TRIGGER handle_employee_auth_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_auth();

-- Update existing employees
DO $$
DECLARE
  emp RECORD;
BEGIN
  FOR emp IN 
    SELECT * FROM employee_profiles 
    WHERE pin IS NOT NULL AND is_active = true
  LOOP
    BEGIN
      -- Update or create auth user
      IF EXISTS (SELECT 1 FROM auth.users WHERE email = emp.email) THEN
        -- Update existing auth user
        UPDATE auth.users 
        SET encrypted_password = crypt(emp.pin, gen_salt('bf')),
            raw_app_meta_data = jsonb_set(
              COALESCE(raw_app_meta_data, '{}'::jsonb),
              '{role}',
              '"employee"'
            ),
            updated_at = NOW()
        WHERE email = emp.email;
      ELSE
        -- Create new auth user
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
          emp.email,
          crypt(emp.pin, gen_salt('bf')),
          NOW(),
          '{"provider":"email","providers":["email"],"role":"employee"}'::jsonb,
          '{}'::jsonb,
          emp.created_at,
          NOW(),
          'authenticated'
        );
      END IF;
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating employee %: %', emp.email, SQLERRM;
    END;
  END LOOP;
END;
$$;