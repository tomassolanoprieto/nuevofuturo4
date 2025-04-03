-- Update supervisor auth entries with correct aud field
DO $$
DECLARE
  v_instance_id UUID;
  v_project_ref TEXT;
  sup RECORD;
BEGIN
  -- Get a valid instance_id from an existing user
  SELECT instance_id INTO v_instance_id 
  FROM auth.users 
  WHERE instance_id IS NOT NULL 
  LIMIT 1;

  IF v_instance_id IS NULL THEN
    RAISE EXCEPTION 'No valid instance_id found';
  END IF;

  -- Get project ref from URL (ydcqmnmblcmkcrdocoqn)
  v_project_ref := 'ydcqmnmblcmkcrdocoqn';

  -- Update all supervisor auth users with the correct aud and other required fields
  FOR sup IN 
    SELECT * FROM supervisor_profiles 
    WHERE is_active = true
  LOOP
    BEGIN
      -- Delete existing auth entry if exists (to ensure clean state)
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
        recovery_sent_at,
        last_sign_in_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        phone_confirmed_at,
        confirmation_sent_at,
        email_change_confirm_status,
        banned_until,
        reauthentication_sent_at
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
        NULL,
        NULL,
        jsonb_build_object(
          'provider', 'email',
          'providers', ARRAY['email'],
          'role', 'supervisor'
        ),
        jsonb_build_object(
          'work_centers', sup.work_centers,
          'country', 'España',
          'timezone', 'Europe/Madrid'
        ),
        sup.created_at,
        NOW(),
        NULL,
        NULL,
        0,
        NULL,
        NULL
      );
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating supervisor %: %', sup.email, SQLERRM;
    END;
  END LOOP;
END;
$$;