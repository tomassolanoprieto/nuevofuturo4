-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;
DROP FUNCTION IF EXISTS handle_supervisor_auth();

-- Create improved supervisor authentication function
CREATE OR REPLACE FUNCTION handle_supervisor_auth()
RETURNS TRIGGER AS $$
DECLARE
  v_instance_id UUID;
  v_project_ref TEXT;
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

  IF NEW.document_type IS NULL THEN
    RAISE EXCEPTION 'Document type is required';
  END IF;

  IF NEW.document_number IS NULL THEN
    RAISE EXCEPTION 'Document number is required';
  END IF;

  -- Get instance_id and project_ref
  v_project_ref := 'ydcqmnmblcmkcrdocoqn';
  SELECT instance_id INTO v_instance_id 
  FROM auth.users 
  WHERE instance_id IS NOT NULL
  LIMIT 1;

  IF v_instance_id IS NULL THEN
    RAISE EXCEPTION 'No valid instance_id found';
  END IF;

  -- Check if user exists by email
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = NEW.email) THEN
    -- Get existing user's ID
    SELECT id INTO NEW.id FROM auth.users WHERE email = NEW.email;
  ELSE
    -- Generate new UUID if user doesn't exist
    NEW.id := gen_random_uuid();
  END IF;

  -- Create or update auth user entry
  INSERT INTO auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    email_change_confirm_status,
    is_super_admin,
    phone_confirmed_at,
    confirmation_sent_at,
    recovery_sent_at,
    email_change_token_current,
    banned_until,
    reauthentication_sent_at,
    is_sso_user,
    deleted_at
  )
  VALUES (
    NEW.id,
    v_instance_id,
    v_project_ref,
    'authenticated',
    NEW.email,
    crypt(NEW.pin, gen_salt('bf')),
    NOW(),
    jsonb_build_object(
      'provider', 'email',
      'providers', ARRAY['email'],
      'role', 'supervisor'
    ),
    jsonb_build_object(
      'work_centers', NEW.work_centers,
      'country', 'España',
      'timezone', 'Europe/Madrid',
      'document_type', NEW.document_type,
      'document_number', NEW.document_number
    ),
    NOW(),
    NOW(),
    0,
    false,
    NULL,
    NULL,
    NULL,
    '',
    NULL,
    NULL,
    false,
    NULL
  )
  ON CONFLICT (id) DO UPDATE
  SET instance_id = EXCLUDED.instance_id,
      aud = EXCLUDED.aud,
      encrypted_password = EXCLUDED.encrypted_password,
      email_confirmed_at = EXCLUDED.email_confirmed_at,
      raw_app_meta_data = EXCLUDED.raw_app_meta_data,
      raw_user_meta_data = EXCLUDED.raw_user_meta_data,
      updated_at = EXCLUDED.updated_at;

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
  v_instance_id UUID;
  v_project_ref TEXT := 'ydcqmnmblcmkcrdocoqn';
  sup RECORD;
BEGIN
  -- Get instance_id
  SELECT instance_id INTO v_instance_id 
  FROM auth.users 
  WHERE instance_id IS NOT NULL
  LIMIT 1;

  IF v_instance_id IS NULL THEN
    RAISE EXCEPTION 'No valid instance_id found';
  END IF;

  -- Update all supervisor auth users
  FOR sup IN 
    SELECT * FROM supervisor_profiles 
    WHERE is_active = true
  LOOP
    BEGIN
      -- Create or update auth entry
      INSERT INTO auth.users (
        id,
        instance_id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        email_change_confirm_status,
        is_super_admin,
        phone_confirmed_at,
        confirmation_sent_at,
        recovery_sent_at,
        email_change_token_current,
        banned_until,
        reauthentication_sent_at,
        is_sso_user,
        deleted_at
      )
      VALUES (
        sup.id,
        v_instance_id,
        v_project_ref,
        'authenticated',
        sup.email,
        crypt(sup.pin, gen_salt('bf')),
        NOW(),
        jsonb_build_object(
          'provider', 'email',
          'providers', ARRAY['email'],
          'role', 'supervisor'
        ),
        jsonb_build_object(
          'work_centers', sup.work_centers,
          'country', 'España',
          'timezone', 'Europe/Madrid',
          'document_type', COALESCE(sup.document_type, 'DNI'),
          'document_number', COALESCE(sup.document_number, '')
        ),
        sup.created_at,
        NOW(),
        0,
        false,
        NULL,
        NULL,
        NULL,
        '',
        NULL,
        NULL,
        false,
        NULL
      )
      ON CONFLICT (id) DO UPDATE
      SET instance_id = EXCLUDED.instance_id,
          aud = EXCLUDED.aud,
          encrypted_password = EXCLUDED.encrypted_password,
          email_confirmed_at = EXCLUDED.email_confirmed_at,
          raw_app_meta_data = EXCLUDED.raw_app_meta_data,
          raw_user_meta_data = EXCLUDED.raw_user_meta_data,
          updated_at = EXCLUDED.updated_at;
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating supervisor %: %', sup.email, SQLERRM;
    END;
  END LOOP;
END;
$$;