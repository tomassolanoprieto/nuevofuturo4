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

  -- Check if user exists by email first
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = NEW.email;

  IF v_user_id IS NOT NULL THEN
    -- Use existing user's ID
    NEW.id := v_user_id;
    
    -- Update existing auth user
    UPDATE auth.users 
    SET encrypted_password = crypt(NEW.pin, gen_salt('bf')),
        raw_app_meta_data = jsonb_build_object(
          'provider', 'email',
          'providers', ARRAY['email'],
          'role', 'supervisor'
        ),
        raw_user_meta_data = jsonb_build_object(
          'work_centers', NEW.work_centers,
          'document_type', NEW.document_type,
          'document_number', NEW.document_number
        ),
        updated_at = NOW()
    WHERE id = v_user_id;
  ELSE
    -- Generate new UUID for new user
    NEW.id := gen_random_uuid();

    -- Create new auth user
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
      is_super_admin
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
        'document_number', NEW.document_number
      ),
      NOW(),
      NOW(),
      'authenticated',
      false
    );
  END IF;

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
BEGIN
  FOR sup IN 
    SELECT * FROM supervisor_profiles 
    WHERE is_active = true
  LOOP
    BEGIN
      -- Check if auth user exists
      IF EXISTS (SELECT 1 FROM auth.users WHERE email = sup.email) THEN
        -- Update existing auth user
        UPDATE auth.users 
        SET encrypted_password = crypt(sup.pin, gen_salt('bf')),
            raw_app_meta_data = jsonb_build_object(
              'provider', 'email',
              'providers', ARRAY['email'],
              'role', 'supervisor'
            ),
            raw_user_meta_data = jsonb_build_object(
              'work_centers', sup.work_centers,
              'document_type', COALESCE(sup.document_type, 'DNI'),
              'document_number', COALESCE(sup.document_number, '')
            ),
            updated_at = NOW()
        WHERE email = sup.email;
      ELSE
        -- Create new auth user
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
          is_super_admin
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
            'document_number', COALESCE(sup.document_number, '')
          ),
          sup.created_at,
          NOW(),
          'authenticated',
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