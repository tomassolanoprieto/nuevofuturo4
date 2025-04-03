-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;
DROP FUNCTION IF EXISTS handle_supervisor_auth();

-- Create improved supervisor authentication function with better ID handling
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

  -- Try to find existing user first
  DECLARE
    existing_user_id UUID;
  BEGIN
    SELECT id INTO existing_user_id
    FROM auth.users
    WHERE email = NEW.email;

    IF existing_user_id IS NOT NULL THEN
      -- Use existing user's ID
      NEW.id := existing_user_id;
    END IF;
  END;

  -- Create or update auth user
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
    COALESCE(NEW.id, gen_random_uuid()),
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
  )
  ON CONFLICT (email) DO UPDATE
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
  RETURNING id INTO NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create new trigger
CREATE TRIGGER handle_supervisor_auth_trigger
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_auth();

-- Drop existing policies
DROP POLICY IF EXISTS "Companies can view their supervisors" ON supervisor_profiles;
DROP POLICY IF EXISTS "Companies can create supervisors" ON supervisor_profiles;
DROP POLICY IF EXISTS "Companies can update their supervisors" ON supervisor_profiles;
DROP POLICY IF EXISTS "Supervisors can view own profile" ON supervisor_profiles;
DROP POLICY IF EXISTS "Supervisors access" ON supervisor_profiles;

-- Create single, comprehensive policy
CREATE POLICY "supervisor_access_policy"
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
      -- Update auth entries with proper password hashing
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
        sup.id,
        sup.email,
        crypt(sup.pin, gen_salt('bf')),
        NOW(),
        jsonb_build_object(
          'provider', 'email',
          'providers', ARRAY['email'],
          'role', 'supervisor'
        ),
        jsonb_build_object(
          'work_centers', sup.work_centers
        ),
        sup.created_at,
        NOW(),
        'authenticated'
      )
      ON CONFLICT (id) DO UPDATE
      SET encrypted_password = crypt(sup.pin, gen_salt('bf')),
          raw_app_meta_data = jsonb_build_object(
            'provider', 'email',
            'providers', ARRAY['email'],
            'role', 'supervisor'
          ),
          raw_user_meta_data = jsonb_build_object(
            'work_centers', sup.work_centers
          ),
          updated_at = NOW();
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating supervisor %: %', sup.email, SQLERRM;
    END;
  END LOOP;
END;
$$;