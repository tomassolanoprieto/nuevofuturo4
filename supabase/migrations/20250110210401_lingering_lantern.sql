-- Extract project ref from instance_id and update aud for supervisors
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

  -- Update all supervisor auth users with the correct aud
  FOR sup IN 
    SELECT * FROM supervisor_profiles 
    WHERE is_active = true
  LOOP
    BEGIN
      UPDATE auth.users 
      SET instance_id = v_instance_id,
          aud = v_project_ref,
          encrypted_password = crypt(sup.pin, gen_salt('bf')),
          email_confirmed_at = NOW(),
          confirmed_at = NOW(),
          raw_app_meta_data = jsonb_build_object(
            'provider', 'email',
            'providers', ARRAY['email'],
            'role', 'supervisor'
          ),
          raw_user_meta_data = jsonb_build_object(
            'work_centers', sup.work_centers,
            'country', 'España',
            'timezone', 'Europe/Madrid'
          ),
          updated_at = NOW()
      WHERE id = sup.id;

      IF NOT FOUND THEN
        INSERT INTO auth.users (
          id,
          email,
          encrypted_password,
          email_confirmed_at,
          confirmed_at,
          aud,
          raw_app_meta_data,
          raw_user_meta_data,
          created_at,
          updated_at,
          role,
          instance_id
        )
        VALUES (
          sup.id,
          sup.email,
          crypt(sup.pin, gen_salt('bf')),
          NOW(),
          NOW(),
          v_project_ref,
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
          'authenticated',
          v_instance_id
        );
      END IF;
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating supervisor %: %', sup.email, SQLERRM;
    END;
  END LOOP;
END;
$$;