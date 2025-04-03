-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_supervisor_creation_trigger ON supervisor_profiles;
DROP FUNCTION IF EXISTS handle_supervisor_creation();

-- Create improved supervisor creation function
CREATE OR REPLACE FUNCTION handle_supervisor_creation()
RETURNS TRIGGER AS $$
BEGIN
  -- Generate new UUID for the supervisor if not provided
  IF NEW.id IS NULL THEN
    NEW.id := gen_random_uuid();
  END IF;

  -- Basic validation
  IF NEW.email IS NULL THEN
    RAISE EXCEPTION 'El email es obligatorio';
  END IF;

  IF NEW.fiscal_name IS NULL THEN
    RAISE EXCEPTION 'El nombre es obligatorio';
  END IF;

  -- Set default values
  NEW.country := COALESCE(NEW.country, 'España');
  NEW.timezone := COALESCE(NEW.timezone, 'Europe/Madrid');
  NEW.is_active := COALESCE(NEW.is_active, true);
  NEW.pin := COALESCE(NEW.pin, LPAD(floor(random() * 1000000)::text, 6, '0'));
  NEW.phone := COALESCE(NEW.phone, '');
  NEW.created_at := COALESCE(NEW.created_at, NOW());
  NEW.updated_at := NOW();

  -- Ensure work_centers is an array
  IF NEW.work_centers IS NULL THEN
    NEW.work_centers := ARRAY[]::work_center_enum[];
  END IF;

  -- Ensure delegations is an array
  IF NEW.delegations IS NULL THEN
    NEW.delegations := ARRAY[]::delegation_enum[];
  END IF;

  -- Validate supervisor type and assignments
  IF NEW.supervisor_type = 'center' AND array_length(NEW.work_centers, 1) IS NULL THEN
    RAISE EXCEPTION 'Los centros de trabajo son obligatorios para supervisores de centro';
  END IF;

  IF NEW.supervisor_type = 'delegation' AND array_length(NEW.delegations, 1) IS NULL THEN
    RAISE EXCEPTION 'Las delegaciones son obligatorias para supervisores de delegación';
  END IF;

  -- Create auth user
  BEGIN
    INSERT INTO auth.users (
      id,
      email,
      encrypted_password,
      email_confirmed_at,
      role,
      raw_app_meta_data
    )
    VALUES (
      NEW.id,
      NEW.email,
      crypt(NEW.pin, gen_salt('bf')),
      NOW(),
      'authenticated',
      jsonb_build_object(
        'provider', 'email',
        'providers', ARRAY['email'],
        'role', 'supervisor',
        'supervisor_type', NEW.supervisor_type
      )
    );
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'Ya existe un usuario con el email %', NEW.email;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for supervisor creation
CREATE TRIGGER handle_supervisor_creation_trigger
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_creation();

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_email ON supervisor_profiles(email);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_company_id ON supervisor_profiles(company_id);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_is_active ON supervisor_profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_work_centers ON supervisor_profiles USING gin(work_centers);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_delegations ON supervisor_profiles USING gin(delegations);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_supervisor_type ON supervisor_profiles(supervisor_type);