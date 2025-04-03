-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;
DROP FUNCTION IF EXISTS handle_supervisor_auth();

-- Create improved supervisor authentication function
CREATE OR REPLACE FUNCTION handle_supervisor_auth()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_instance_id UUID;
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

  -- Get instance_id from an existing user
  SELECT instance_id INTO v_instance_id 
  FROM auth.users 
  WHERE instance_id IS NOT NULL 
  LIMIT 1;

  -- Check if user exists by email
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = NEW.email;

  IF v_user_id IS NOT NULL THEN
    RAISE EXCEPTION 'Email already exists';
  END IF;

  -- Generate new UUID for the supervisor
  NEW.id := gen_random_uuid();

  -- Create auth user
  INSERT INTO auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    confirmed_at,
    recovery_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    created_at,
    updated_at,
    phone_confirmed_at,
    confirmation_sent_at,
    email_change_confirm_status,
    banned_until,
    reauthentication_sent_at,
    is_super_admin,
    is_sso_user
  )
  VALUES (
    NEW.id,
    v_instance_id,
    'ydcqmnmblcmkcrdocoqn',
    'authenticated',
    NEW.email,
    crypt(NEW.pin, gen_salt('bf')),
    NOW(),
    NOW(),
    NULL,
    NULL,
    jsonb_build_object(
      'provider', 'email',
      'providers', ARRAY['email'],
      'role', 'supervisor'
    ),
    NOW(),
    NOW(),
    NULL,
    NULL,
    0,
    NULL,
    NULL,
    false,
    false
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create new trigger
CREATE TRIGGER handle_supervisor_auth_trigger
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_auth();

-- Update existing supervisors
DO $$
DECLARE
  sup RECORD;
  v_instance_id UUID;
BEGIN
  -- Get instance_id from an existing user
  SELECT instance_id INTO v_instance_id 
  FROM auth.users 
  WHERE instance_id IS NOT NULL 
  LIMIT 1;

  FOR sup IN 
    SELECT * FROM supervisor_profiles 
    WHERE is_active = true
  LOOP
    BEGIN
      -- Update auth user
      UPDATE auth.users 
      SET instance_id = v_instance_id,
          aud = 'ydcqmnmblcmkcrdocoqn',
          encrypted_password = crypt(sup.pin, gen_salt('bf')),
          email_confirmed_at = NOW(),
          confirmed_at = NOW(),
          raw_app_meta_data = jsonb_build_object(
            'provider', 'email',
            'providers', ARRAY['email'],
            'role', 'supervisor'
          ),
          updated_at = NOW()
      WHERE id = sup.id;

      IF NOT FOUND THEN
        -- Create new auth user if update failed
        INSERT INTO auth.users (
          id,
          instance_id,
          aud,
          role,
          email,
          encrypted_password,
          email_confirmed_at,
          confirmed_at,
          raw_app_meta_data,
          created_at,
          updated_at,
          email_change_confirm_status,
          is_super_admin,
          is_sso_user
        )
        VALUES (
          sup.id,
          v_instance_id,
          'ydcqmnmblcmkcrdocoqn',
          'authenticated',
          sup.email,
          crypt(sup.pin, gen_salt('bf')),
          NOW(),
          NOW(),
          jsonb_build_object(
            'provider', 'email',
            'providers', ARRAY['email'],
            'role', 'supervisor'
          ),
          sup.created_at,
          NOW(),
          0,
          false,
          false
        );
      END IF;
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating supervisor %: %', sup.email, SQLERRM;
    END;
  END LOOP;
END;
$$;