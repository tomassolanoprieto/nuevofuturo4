-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_employee_import_trigger ON employee_profiles;
DROP FUNCTION IF EXISTS handle_employee_import();

-- Drop existing policies first
DROP POLICY IF EXISTS "employee_access" ON employee_profiles;
DROP POLICY IF EXISTS "employee_access_policy" ON employee_profiles;
DROP POLICY IF EXISTS "employee_profile_access" ON employee_profiles;
DROP POLICY IF EXISTS "employee_data_access" ON employee_profiles;
DROP POLICY IF EXISTS "employee_data_access_policy" ON employee_profiles;
DROP POLICY IF EXISTS "employee_profiles_policy" ON employee_profiles;
DROP POLICY IF EXISTS "allow_all" ON employee_profiles;

-- Create super simplified employee import function
CREATE OR REPLACE FUNCTION handle_employee_import()
RETURNS TRIGGER AS $$
BEGIN
  -- Generate new UUID for the employee
  NEW.id := gen_random_uuid();

  -- Create auth user FIRST, before the employee profile
  INSERT INTO auth.users (
    id,  -- Use the same ID we just generated
    email,
    encrypted_password,
    role
  )
  VALUES (
    NEW.id,  -- Use the same ID here
    NEW.email,
    crypt(COALESCE(NEW.pin, LPAD(floor(random() * 1000000)::text, 6, '0')), gen_salt('bf')),
    'authenticated'
  );

  -- Set default values for employee profile
  NEW.country := COALESCE(NEW.country, 'España');
  NEW.timezone := COALESCE(NEW.timezone, 'Europe/Madrid');
  NEW.is_active := COALESCE(NEW.is_active, true);
  NEW.work_centers := COALESCE(NEW.work_centers, ARRAY[]::work_center_enum[]);
  NEW.job_positions := COALESCE(NEW.job_positions, ARRAY[]::job_position_enum[]);

  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'El email ya existe';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al crear empleado: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger that runs BEFORE INSERT
CREATE TRIGGER handle_employee_import_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_import();

-- Create simple policy with unique name
CREATE POLICY "employee_profiles_access_policy_v1"
  ON employee_profiles
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Drop all not-null constraints from auth.users
ALTER TABLE auth.users
ALTER COLUMN instance_id DROP NOT NULL,
ALTER COLUMN aud DROP NOT NULL,
ALTER COLUMN role DROP NOT NULL,
ALTER COLUMN email_confirmed_at DROP NOT NULL,
ALTER COLUMN raw_app_meta_data DROP NOT NULL,
ALTER COLUMN raw_user_meta_data DROP NOT NULL,
ALTER COLUMN created_at DROP NOT NULL,
ALTER COLUMN updated_at DROP NOT NULL,
ALTER COLUMN confirmation_sent_at DROP NOT NULL,
ALTER COLUMN is_super_admin DROP NOT NULL,
ALTER COLUMN phone_confirmed_at DROP NOT NULL,
ALTER COLUMN confirmed_at DROP NOT NULL,
ALTER COLUMN recovery_sent_at DROP NOT NULL,
ALTER COLUMN email_change_token_current DROP NOT NULL,
ALTER COLUMN email_change_confirm_status DROP NOT NULL,
ALTER COLUMN banned_until DROP NOT NULL,
ALTER COLUMN reauthentication_sent_at DROP NOT NULL,
ALTER COLUMN is_sso_user DROP NOT NULL,
ALTER COLUMN deleted_at DROP NOT NULL;