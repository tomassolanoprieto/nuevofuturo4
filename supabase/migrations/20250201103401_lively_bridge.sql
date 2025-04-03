-- Drop existing policies and triggers
DROP POLICY IF EXISTS "Supervisors can view own profile" ON supervisor_profiles;
DROP POLICY IF EXISTS "Companies can manage supervisors" ON supervisor_profiles;
DROP POLICY IF EXISTS "Supervisors can view employee data" ON employee_profiles;
DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;
DROP FUNCTION IF EXISTS handle_supervisor_auth();

-- Create improved supervisor authentication function
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

  IF NEW.supervisor_type NOT IN ('center', 'delegation') THEN
    RAISE EXCEPTION 'Invalid supervisor type';
  END IF;

  -- Generate new UUID for the supervisor
  NEW.id := gen_random_uuid();

  -- Create auth user
  INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    role,
    confirmed_at
  )
  VALUES (
    NEW.id,
    NEW.email,
    crypt(NEW.pin, gen_salt('bf')),
    NOW(),
    jsonb_build_object(
      'provider', 'email',
      'providers', ARRAY['email'],
      'role', 'supervisor',
      'supervisor_type', NEW.supervisor_type
    ),
    jsonb_build_object(
      'work_centers', NEW.work_centers,
      'delegations', NEW.delegations
    ),
    'authenticated',
    NOW()
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
CREATE TRIGGER handle_supervisor_auth_trigger
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_auth();

-- Create simplified policies
CREATE POLICY "Supervisor access"
  ON supervisor_profiles
  FOR ALL
  TO authenticated
  USING (
    id = auth.uid() OR 
    company_id = auth.uid()
  )
  WITH CHECK (
    company_id = auth.uid()
  );

-- Create policy for employee data access
CREATE POLICY "Supervisor employee access"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = employee_profiles.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND employee_profiles.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND employee_profiles.delegation = ANY(sp.delegations))
      )
    )
  );

-- Update existing supervisors
DO $$
DECLARE
  sup RECORD;
BEGIN
  FOR sup IN 
    SELECT * FROM supervisor_profiles 
    WHERE is_active = true
  LOOP
    BEGIN
      -- Update auth user
      UPDATE auth.users 
      SET encrypted_password = crypt(sup.pin, gen_salt('bf')),
          email_confirmed_at = NOW(),
          confirmed_at = NOW(),
          raw_app_meta_data = jsonb_build_object(
            'provider', 'email',
            'providers', ARRAY['email'],
            'role', 'supervisor',
            'supervisor_type', sup.supervisor_type
          ),
          raw_user_meta_data = jsonb_build_object(
            'work_centers', sup.work_centers,
            'delegations', sup.delegations
          )
      WHERE id = sup.id;

      IF NOT FOUND THEN
        -- Create new auth user if not exists
        INSERT INTO auth.users (
          id,
          email,
          encrypted_password,
          email_confirmed_at,
          raw_app_meta_data,
          raw_user_meta_data,
          role,
          confirmed_at
        )
        VALUES (
          sup.id,
          sup.email,
          crypt(sup.pin, gen_salt('bf')),
          NOW(),
          jsonb_build_object(
            'provider', 'email',
            'providers', ARRAY['email'],
            'role', 'supervisor',
            'supervisor_type', sup.supervisor_type
          ),
          jsonb_build_object(
            'work_centers', sup.work_centers,
            'delegations', sup.delegations
          ),
          'authenticated',
          NOW()
        );
      END IF;
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating supervisor %: %', sup.email, SQLERRM;
    END;
  END LOOP;
END;
$$;