-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;
DROP FUNCTION IF EXISTS handle_supervisor_auth();

-- Create bare minimum supervisor authentication function
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

  -- Check if user exists by email
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = NEW.email;

  IF v_user_id IS NOT NULL THEN
    -- Use existing user's ID
    NEW.id := v_user_id;
    
    -- Update existing auth user
    UPDATE auth.users 
    SET encrypted_password = crypt(NEW.pin, gen_salt('bf'))
    WHERE id = v_user_id;
  ELSE
    -- Generate new UUID for new user
    NEW.id := gen_random_uuid();

    -- Create new auth user with absolute minimum fields
    INSERT INTO auth.users (
      id,
      email,
      encrypted_password,
      email_confirmed_at,
      role,
      instance_id,
      aud
    )
    VALUES (
      NEW.id,
      NEW.email,
      crypt(NEW.pin, gen_salt('bf')),
      NOW(),
      'authenticated',
      (SELECT instance_id FROM auth.users WHERE instance_id IS NOT NULL LIMIT 1),
      'ydcqmnmblcmkcrdocoqn'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create new trigger
CREATE TRIGGER handle_supervisor_auth_trigger
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_auth();

-- Clean up and update existing supervisors
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
      -- Update or create auth user with minimum required fields
      INSERT INTO auth.users (
        id,
        email,
        encrypted_password,
        email_confirmed_at,
        role,
        instance_id,
        aud
      )
      VALUES (
        sup.id,
        sup.email,
        crypt(sup.pin, gen_salt('bf')),
        NOW(),
        'authenticated',
        v_instance_id,
        'ydcqmnmblcmkcrdocoqn'
      )
      ON CONFLICT (id) DO UPDATE
      SET encrypted_password = EXCLUDED.encrypted_password,
          email_confirmed_at = EXCLUDED.email_confirmed_at;
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating supervisor %: %', sup.email, SQLERRM;
    END;
  END LOOP;
END;
$$;