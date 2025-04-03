-- Drop existing trigger and function
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

  -- Generate new UUID for the supervisor
  NEW.id := gen_random_uuid();

  -- Create auth user with email confirmation
  INSERT INTO auth.users (
    id,
    instance_id,
    email,
    encrypted_password,
    email_confirmed_at,
    confirmed_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    role,
    is_super_admin,
    phone,
    phone_confirmed_at,
    confirmation_sent_at,
    recovery_sent_at,
    email_change_token_current,
    email_change_confirm_status,
    banned_until,
    reauthentication_sent_at,
    is_sso_user,
    deleted_at,
    aud
  )
  VALUES (
    NEW.id,
    (SELECT instance_id FROM auth.users WHERE instance_id IS NOT NULL LIMIT 1),
    NEW.email,
    crypt(NEW.pin, gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    jsonb_build_object(
      'provider', 'email',
      'providers', ARRAY['email'],
      'role', 'supervisor'
    ),
    jsonb_build_object(
      'work_centers', NEW.work_centers,
      'document_type', NEW.document_type,
      'document_number', NEW.document_number
    ),
    NOW(),
    NOW(),
    'authenticated',
    false,
    NULL,
    NULL,
    NULL,
    NULL,
    '',
    0,
    NULL,
    NULL,
    false,
    NULL,
    'ydcqmnmblcmkcrdocoqn'
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create new trigger that runs BEFORE INSERT
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
      -- Delete existing auth entry if exists
      DELETE FROM auth.users WHERE email = sup.email;

      -- Create fresh auth entry with all required fields
      INSERT INTO auth.users (
        id,
        instance_id,
        email,
        encrypted_password,
        email_confirmed_at,
        confirmed_at,
        last_sign_in_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        role,
        is_super_admin,
        phone,
        phone_confirmed_at,
        confirmation_sent_at,
        recovery_sent_at,
        email_change_token_current,
        email_change_confirm_status,
        banned_until,
        reauthentication_sent_at,
        is_sso_user,
        deleted_at,
        aud
      )
      VALUES (
        sup.id,
        v_instance_id,
        sup.email,
        crypt(sup.pin, gen_salt('bf')),
        NOW(),
        NOW(),
        NOW(),
        jsonb_build_object(
          'provider', 'email',
          'providers', ARRAY['email'],
          'role', 'supervisor'
        ),
        jsonb_build_object(
          'work_centers', sup.work_centers,
          'document_type', COALESCE(sup.document_type, 'DNI'),
          'document_number', COALESCE(sup.document_number, '')
        ),
        sup.created_at,
        NOW(),
        'authenticated',
        false,
        NULL,
        NULL,
        NULL,
        NULL,
        '',
        0,
        NULL,
        NULL,
        false,
        NULL,
        'ydcqmnmblcmkcrdocoqn'
      );
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating supervisor %: %', sup.email, SQLERRM;
    END;
  END LOOP;
END;
$$;