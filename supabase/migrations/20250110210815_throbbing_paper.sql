-- Add document fields to supervisor_profiles
ALTER TABLE supervisor_profiles
ADD COLUMN IF NOT EXISTS document_type TEXT CHECK (document_type IN ('DNI', 'NIE', 'Pasaporte')),
ADD COLUMN IF NOT EXISTS document_number TEXT;

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

  -- Get instance_id and project_ref from an existing user
  SELECT instance_id, aud INTO v_instance_id, v_project_ref
  FROM auth.users 
  WHERE instance_id IS NOT NULL AND aud IS NOT NULL
  LIMIT 1;

  IF v_instance_id IS NULL OR v_project_ref IS NULL THEN
    RAISE EXCEPTION 'No valid instance_id or aud found';
  END IF;

  -- Create auth user with all required fields
  INSERT INTO auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    confirmed_at,
    last_sign_in_at,
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
    email_change_confirm_status,
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
    NOW(),
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
    0,
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
      confirmed_at = EXCLUDED.confirmed_at,
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

-- Update existing supervisors with document fields and correct auth entries
DO $$
DECLARE
  v_instance_id UUID;
  v_project_ref TEXT;
  sup RECORD;
BEGIN
  -- Get instance_id and project_ref from an existing user
  SELECT instance_id, aud INTO v_instance_id, v_project_ref
  FROM auth.users 
  WHERE instance_id IS NOT NULL AND aud IS NOT NULL
  LIMIT 1;

  IF v_instance_id IS NULL OR v_project_ref IS NULL THEN
    RAISE EXCEPTION 'No valid instance_id or aud found';
  END IF;

  -- Update all supervisor auth users
  FOR sup IN 
    SELECT * FROM supervisor_profiles 
    WHERE is_active = true
  LOOP
    BEGIN
      -- Update supervisor profile with document fields if not set
      UPDATE supervisor_profiles
      SET document_type = COALESCE(document_type, 'DNI'),
          document_number = COALESCE(document_number, '')
      WHERE id = sup.id;

      -- Delete existing auth entry if exists
      DELETE FROM auth.users WHERE id = sup.id;

      -- Create new auth entry with all required fields
      INSERT INTO auth.users (
        id,
        instance_id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        confirmed_at,
        last_sign_in_at,
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
        NOW(),
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
          'document_type', sup.document_type,
          'document_number', sup.document_number
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
      );
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating supervisor %: %', sup.email, SQLERRM;
    END;
  END LOOP;
END;
$$;