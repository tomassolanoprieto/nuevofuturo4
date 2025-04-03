-- Update existing company if exists, otherwise insert new one
DO $$
DECLARE
  v_user_id UUID;
  v_instance_id UUID;
BEGIN
  -- Get instance_id from existing user
  SELECT instance_id INTO v_instance_id 
  FROM auth.users 
  WHERE instance_id IS NOT NULL 
  LIMIT 1;

  -- Check if user exists
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = 'empresa@nuevofuturo.com';

  IF v_user_id IS NULL THEN
    -- Create new auth user if doesn't exist
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      role
    )
    VALUES (
      gen_random_uuid(),
      v_instance_id,
      'empresa@nuevofuturo.com',
      crypt('nuevofuturo2025', gen_salt('bf')),
      NOW(),
      jsonb_build_object(
        'provider', 'email',
        'providers', ARRAY['email'],
        'role', 'company'
      ),
      jsonb_build_object(
        'country', 'España',
        'timezone', 'Europe/Madrid'
      ),
      'authenticated'
    )
    RETURNING id INTO v_user_id;

    -- Create company profile
    INSERT INTO company_profiles (
      id,
      fiscal_name,
      email,
      phone,
      country,
      timezone,
      roles,
      created_at,
      updated_at
    )
    VALUES (
      v_user_id,
      'Nuevo Futuro',
      'empresa@nuevofuturo.com',
      '777777777',
      'España',
      'Europe/Madrid',
      ARRAY['company'],
      NOW(),
      NOW()
    );
  ELSE
    -- Update existing auth user
    UPDATE auth.users 
    SET
      encrypted_password = crypt('nuevofuturo2025', gen_salt('bf')),
      email_confirmed_at = NOW(),
      raw_app_meta_data = jsonb_build_object(
        'provider', 'email',
        'providers', ARRAY['email'],
        'role', 'company'
      ),
      raw_user_meta_data = jsonb_build_object(
        'country', 'España',
        'timezone', 'Europe/Madrid'
      )
    WHERE id = v_user_id;

    -- Update or insert company profile
    INSERT INTO company_profiles (
      id,
      fiscal_name,
      email,
      phone,
      country,
      timezone,
      roles,
      created_at,
      updated_at
    )
    VALUES (
      v_user_id,
      'Nuevo Futuro',
      'empresa@nuevofuturo.com',
      '777777777',
      'España',
      'Europe/Madrid',
      ARRAY['company'],
      NOW(),
      NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET
      fiscal_name = EXCLUDED.fiscal_name,
      phone = EXCLUDED.phone,
      country = EXCLUDED.country,
      timezone = EXCLUDED.timezone,
      roles = EXCLUDED.roles,
      updated_at = NOW();
  END IF;
END $$;