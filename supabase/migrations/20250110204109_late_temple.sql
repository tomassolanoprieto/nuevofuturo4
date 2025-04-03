-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;
DROP FUNCTION IF EXISTS handle_supervisor_auth();

-- Create improved supervisor authentication function
CREATE OR REPLACE FUNCTION handle_supervisor_auth()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
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

  -- Generate UUID first
  NEW.id := gen_random_uuid();

  -- Create auth user with the SAME ID as the profile
  INSERT INTO auth.users (
    id,              -- Use the same ID we just generated
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
    NEW.id,          -- Use the same ID
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
  WHEN unique_violation THEN
    -- If email already exists, update the user
    SELECT id INTO v_user_id FROM auth.users WHERE email = NEW.email;
    
    IF v_user_id IS NOT NULL THEN
      NEW.id := v_user_id;
      
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
      WHERE id = v_user_id;
    END IF;
    
    RETURN NEW;
  WHEN others THEN
    RAISE EXCEPTION 'Error creating supervisor: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create new trigger
CREATE TRIGGER handle_supervisor_auth_trigger
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_auth();

-- Drop and recreate policies with better permissions
DROP POLICY IF EXISTS "Companies can view their supervisors" ON supervisor_profiles;
DROP POLICY IF EXISTS "Companies can create supervisors" ON supervisor_profiles;
DROP POLICY IF EXISTS "Companies can update their supervisors" ON supervisor_profiles;
DROP POLICY IF EXISTS "Supervisors can view own profile" ON supervisor_profiles;

-- Companies can view their supervisors
CREATE POLICY "Companies can view their supervisors"
  ON supervisor_profiles
  FOR SELECT
  TO authenticated
  USING (
    company_id = auth.uid() OR
    id = auth.uid()
  );

-- Companies can create supervisors
CREATE POLICY "Companies can create supervisors"
  ON supervisor_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (company_id = auth.uid());

-- Companies can update their supervisors
CREATE POLICY "Companies can update their supervisors"
  ON supervisor_profiles
  FOR UPDATE
  TO authenticated
  USING (company_id = auth.uid());

-- Update existing supervisors to ensure auth entries
DO $$
DECLARE
  sup RECORD;
BEGIN
  FOR sup IN 
    SELECT * FROM supervisor_profiles 
    WHERE is_active = true
  LOOP
    BEGIN
      -- Ensure auth user exists with correct role
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