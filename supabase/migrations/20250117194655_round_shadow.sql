-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;
DROP FUNCTION IF EXISTS handle_supervisor_auth();

-- Create improved supervisor authentication function
CREATE OR REPLACE FUNCTION handle_supervisor_auth()
RETURNS TRIGGER AS $$
DECLARE
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

  IF v_instance_id IS NULL THEN
    RAISE EXCEPTION 'No valid instance_id found';
  END IF;

  -- Generate new UUID for the supervisor
  NEW.id := gen_random_uuid();

  -- Create auth user with all required fields
  INSERT INTO auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    created_at,
    updated_at,
    is_super_admin,
    confirmed_at,
    last_sign_in_at,
    phone_confirmed_at,
    confirmation_sent_at,
    email_change_confirm_status,
    banned_until,
    reauthentication_sent_at,
    is_sso_user,
    deleted_at
  )
  VALUES (
    NEW.id,
    v_instance_id,
    'authenticated',
    'authenticated',
    NEW.email,
    crypt(NEW.pin, gen_salt('bf')),
    NOW(),
    jsonb_build_object(
      'provider', 'email',
      'providers', ARRAY['email'],
      'role', 'supervisor'
    ),
    NOW(),
    NOW(),
    false,
    NOW(),
    NOW(),
    NULL,
    NULL,
    0,
    NULL,
    NULL,
    false,
    NULL
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create new trigger
CREATE TRIGGER handle_supervisor_auth_trigger
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_auth();

-- Update existing supervisors with correct auth entries
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

  IF v_instance_id IS NULL THEN
    RAISE EXCEPTION 'No valid instance_id found';
  END IF;

  -- Update all existing supervisor auth entries
  FOR sup IN 
    SELECT * FROM supervisor_profiles 
    WHERE is_active = true
  LOOP
    BEGIN
      -- Delete existing auth entry if exists
      DELETE FROM auth.users WHERE email = sup.email;

      -- Create fresh auth entry with all required fields
      INSERT INTO auth.users (
        id,
        instance_id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        created_at,
        updated_at,
        is_super_admin,
        confirmed_at,
        last_sign_in_at,
        phone_confirmed_at,
        confirmation_sent_at,
        email_change_confirm_status,
        banned_until,
        reauthentication_sent_at,
        is_sso_user,
        deleted_at
      )
      VALUES (
        sup.id,
        v_instance_id,
        'authenticated',
        'authenticated',
        sup.email,
        crypt(sup.pin, gen_salt('bf')),
        NOW(),
        jsonb_build_object(
          'provider', 'email',
          'providers', ARRAY['email'],
          'role', 'supervisor'
        ),
        sup.created_at,
        NOW(),
        false,
        NOW(),
        NOW(),
        NULL,
        NULL,
        0,
        NULL,
        NULL,
        false,
        NULL
      );
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating supervisor %: %', sup.email, SQLERRM;
    END;
  END LOOP;
END;
$$;