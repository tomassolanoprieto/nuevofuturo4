-- Add document fields to supervisor_profiles if they don't exist
ALTER TABLE supervisor_profiles
ADD COLUMN IF NOT EXISTS document_type TEXT CHECK (document_type IN ('DNI', 'NIE', 'Pasaporte')),
ADD COLUMN IF NOT EXISTS document_number TEXT;

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_supervisor_auth_trigger ON supervisor_profiles;
DROP FUNCTION IF EXISTS handle_supervisor_auth();

-- Create simplified supervisor authentication function
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

  IF NEW.document_type IS NULL THEN
    RAISE EXCEPTION 'Document type is required';
  END IF;

  IF NEW.document_number IS NULL THEN
    RAISE EXCEPTION 'Document number is required';
  END IF;

  -- Check if user exists by email
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = NEW.email) THEN
    -- Get existing user's ID
    SELECT id INTO NEW.id FROM auth.users WHERE email = NEW.email;
    
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
    WHERE id = NEW.id;
  ELSE
    -- Generate new UUID if user doesn't exist
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
      role
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
      'authenticated'
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
      -- Update auth entries
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
          role
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
          'authenticated'
        );
      END IF;
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating supervisor %: %', sup.email, SQLERRM;
    END;
  END LOOP;
END;
$$;