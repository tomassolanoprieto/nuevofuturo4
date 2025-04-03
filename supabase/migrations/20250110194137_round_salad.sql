/*
  # Update supervisor policies and triggers

  This migration updates the supervisor_profiles table and its associated policies and triggers,
  checking for existence first to avoid conflicts.
*/

-- Drop existing policies if they exist
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Companies can view their supervisors" ON supervisor_profiles;
    DROP POLICY IF EXISTS "Companies can create supervisors" ON supervisor_profiles;
    DROP POLICY IF EXISTS "Companies can update their supervisors" ON supervisor_profiles;
EXCEPTION
    WHEN undefined_object THEN null;
END $$;

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;
DROP TRIGGER IF EXISTS update_supervisor_metadata_trigger ON supervisor_profiles;

-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS handle_supervisor_auth();
DROP FUNCTION IF EXISTS update_supervisor_metadata();

-- Create or replace supervisor authentication function
CREATE OR REPLACE FUNCTION handle_supervisor_auth()
RETURNS TRIGGER AS $$
BEGIN
  -- Basic validation
  IF NEW.email IS NULL THEN
    RAISE EXCEPTION 'Email is required';
  END IF;

  IF NEW.pin IS NULL THEN
    RAISE EXCEPTION 'PIN is required';
  END IF;

  IF NEW.pin !~ '^\d{6}$' THEN
    RAISE EXCEPTION 'PIN must be exactly 6 digits';
  END IF;

  -- Create new auth user
  INSERT INTO auth.users (
    id,
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
    NEW.id,
    NEW.email,
    crypt(NEW.pin, gen_salt('bf')),
    NOW(),
    jsonb_build_object(
      'provider', 'email',
      'providers', ARRAY['email'],
      'role', 'supervisor'
    ),
    jsonb_build_object(
      'work_centers', NEW.work_centers
    ),
    NOW(),
    NOW(),
    'authenticated'
  );

  RETURN NEW;
EXCEPTION
  WHEN others THEN
    -- If there's an error, try to update existing user instead
    UPDATE auth.users 
    SET encrypted_password = crypt(NEW.pin, gen_salt('bf')),
        raw_app_meta_data = jsonb_build_object(
          'provider', 'email',
          'providers', ARRAY['email'],
          'role', 'supervisor'
        ),
        raw_user_meta_data = jsonb_build_object(
          'work_centers', NEW.work_centers
        ),
        updated_at = NOW()
    WHERE email = NEW.email;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create or replace supervisor metadata function
CREATE OR REPLACE FUNCTION update_supervisor_metadata()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE auth.users 
  SET raw_user_meta_data = jsonb_build_object(
    'work_centers', NEW.work_centers
  ),
  updated_at = NOW()
  WHERE id = NEW.id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create new policies
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

-- Create new triggers
CREATE TRIGGER handle_supervisor_auth_trigger
  AFTER INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_auth();

CREATE TRIGGER update_supervisor_metadata_trigger
  AFTER UPDATE OF work_centers ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_supervisor_metadata();