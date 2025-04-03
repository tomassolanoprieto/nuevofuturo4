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

  -- Generate new UUID for the supervisor
  NEW.id := gen_random_uuid();

  -- Create auth user with email confirmation
  INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    role,
    is_super_admin,
    instance_id,
    aud
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
      'work_centers', NEW.work_centers,
      'document_type', NEW.document_type,
      'document_number', NEW.document_number,
      'timezone', NEW.timezone,
      'country', NEW.country,
      'phone', NEW.phone,
      'employee_id', NEW.employee_id
    ),
    NOW(),
    NOW(),
    'authenticated',
    false,
    (SELECT instance_id FROM auth.users WHERE instance_id IS NOT NULL LIMIT 1),
    'ydcqmnmblcmkcrdocoqn'
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
      -- Delete existing auth entry if exists
      DELETE FROM auth.users WHERE email = sup.email;

      -- Create fresh auth entry
      INSERT INTO auth.users (
        id,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        role,
        is_super_admin,
        instance_id,
        aud
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
          'work_centers', sup.work_centers,
          'document_type', COALESCE(sup.document_type, 'DNI'),
          'document_number', COALESCE(sup.document_number, ''),
          'timezone', COALESCE(sup.timezone, 'Europe/Madrid'),
          'country', COALESCE(sup.country, 'España'),
          'phone', COALESCE(sup.phone, ''),
          'employee_id', COALESCE(sup.employee_id, '')
        ),
        sup.created_at,
        NOW(),
        'authenticated',
        false,
        v_instance_id,
        'ydcqmnmblcmkcrdocoqn'
      );
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating supervisor %: %', sup.email, SQLERRM;
    END;
  END LOOP;
END;
$$;