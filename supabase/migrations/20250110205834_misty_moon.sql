-- Update existing supervisors with correct instance_id
DO $$
DECLARE
  v_instance_id UUID;
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

  -- Update all supervisor auth users with the correct instance_id
  UPDATE auth.users
  SET instance_id = v_instance_id
  WHERE id IN (
    SELECT id FROM supervisor_profiles
    WHERE is_active = true
  )
  AND instance_id IS NULL;

  -- Ensure all supervisors have proper auth entries
  FOR sup IN 
    SELECT * FROM supervisor_profiles 
    WHERE is_active = true
  LOOP
    BEGIN
      UPDATE auth.users 
      SET instance_id = v_instance_id,
          encrypted_password = crypt(sup.pin, gen_salt('bf')),
          email_confirmed_at = NOW(),
          raw_app_meta_data = jsonb_build_object(
            'provider', 'email',
            'providers', ARRAY['email'],
            'role', 'supervisor'
          ),
          raw_user_meta_data = jsonb_build_object(
            'work_centers', sup.work_centers
          ),
          updated_at = NOW()
      WHERE id = sup.id;

      IF NOT FOUND THEN
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
          instance_id
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