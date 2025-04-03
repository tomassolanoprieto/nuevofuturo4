-- First drop all triggers
DROP TRIGGER IF EXISTS handle_employee_creation_trigger ON employee_profiles CASCADE;
DROP TRIGGER IF EXISTS handle_supervisor_creation_trigger ON supervisor_profiles CASCADE;
DROP TRIGGER IF EXISTS validate_time_entry_trigger ON time_entries CASCADE;

-- Now we can safely drop the functions
DROP FUNCTION IF EXISTS handle_employee_creation() CASCADE;
DROP FUNCTION IF EXISTS validate_time_entry() CASCADE;
DROP FUNCTION IF EXISTS handle_supervisor_creation() CASCADE;

-- Create improved employee creation function with email check
CREATE OR REPLACE FUNCTION handle_employee_creation()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Generate new UUID for the employee if not provided
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

  -- Check if email already exists
  SELECT id INTO v_user_id FROM auth.users WHERE email = NEW.email;
  IF FOUND THEN
    RAISE EXCEPTION 'Ya existe un usuario con el email %', NEW.email;
  END IF;

  -- Set default values
  NEW.country := COALESCE(NEW.country, 'España');
  NEW.timezone := COALESCE(NEW.timezone, 'Europe/Madrid');
  NEW.is_active := COALESCE(NEW.is_active, true);
  NEW.pin := COALESCE(NEW.pin, LPAD(floor(random() * 1000000)::text, 6, '0'));
  NEW.phone := COALESCE(NEW.phone, '');
  NEW.created_at := COALESCE(NEW.created_at, NOW());
  NEW.updated_at := NOW();

  -- Handle work centers array
  IF NEW.work_centers IS NULL OR array_length(NEW.work_centers, 1) IS NULL THEN
    IF NEW.work_centers[1] IS NOT NULL THEN
      NEW.work_centers := ARRAY[trim(both '"' from trim(both '{}' from NEW.work_centers[1]::text))::work_center_enum];
    ELSE
      NEW.work_centers := ARRAY[]::work_center_enum[];
    END IF;
  END IF;

  -- Handle job positions array
  IF NEW.job_positions IS NULL OR array_length(NEW.job_positions, 1) IS NULL THEN
    IF NEW.job_positions[1] IS NOT NULL THEN
      NEW.job_positions := ARRAY[trim(both '"' from trim(both '{}' from NEW.job_positions[1]::text))::job_position_enum];
    ELSE
      NEW.job_positions := ARRAY[]::job_position_enum[];
    END IF;
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
        'role', 'employee'
      )
    );
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'Ya existe un usuario con el email %', NEW.email;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create improved supervisor creation function with email check
CREATE OR REPLACE FUNCTION handle_supervisor_creation()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Generate new UUID for the supervisor
  NEW.id := gen_random_uuid();

  -- Check if email already exists
  SELECT id INTO v_user_id FROM auth.users WHERE email = NEW.email;
  IF FOUND THEN
    RAISE EXCEPTION 'Ya existe un usuario con el email %', NEW.email;
  END IF;

  -- Set default values
  NEW.country := COALESCE(NEW.country, 'España');
  NEW.timezone := COALESCE(NEW.timezone, 'Europe/Madrid');
  NEW.is_active := COALESCE(NEW.is_active, true);
  NEW.supervisor_type := COALESCE(NEW.supervisor_type, 'center');

  -- Ensure work_centers is an array
  IF NEW.work_centers IS NULL THEN
    NEW.work_centers := ARRAY[]::work_center_enum[];
  END IF;

  -- Convert single work center to array if needed
  IF array_length(NEW.work_centers, 1) IS NULL AND NEW.work_centers[1] IS NOT NULL THEN
    NEW.work_centers := ARRAY[NEW.work_centers[1]]::work_center_enum[];
  END IF;

  -- Ensure delegations is an array
  IF NEW.delegations IS NULL THEN
    NEW.delegations := ARRAY[]::delegation_enum[];
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
        'role', 'supervisor'
      )
    );
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'Ya existe un usuario con el email %', NEW.email;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create improved time entry validation function
CREATE OR REPLACE FUNCTION validate_time_entry()
RETURNS TRIGGER AS $$
BEGIN
  -- Validate work_center for clock_in entries
  IF NEW.entry_type = 'clock_in' THEN
    -- Check if work_center is provided
    IF NEW.work_center IS NULL THEN
      RAISE EXCEPTION 'El centro de trabajo es obligatorio para los fichajes de entrada';
    END IF;

    -- Check if work_center exists in employee's work_centers array
    IF NOT EXISTS (
      SELECT 1
      FROM employee_profiles
      WHERE id = NEW.employee_id
      AND NEW.work_center = ANY(work_centers)
    ) THEN
      RAISE EXCEPTION 'Centro de trabajo no válido para este empleado';
    END IF;

    -- Check if time_type is provided
    IF NEW.time_type IS NULL THEN
      RAISE EXCEPTION 'El tipo de fichaje es obligatorio para los fichajes de entrada';
    END IF;

    -- Validate time_type
    IF NEW.time_type NOT IN ('turno', 'coordinacion', 'formacion', 'sustitucion', 'otros') THEN
      RAISE EXCEPTION 'Tipo de fichaje no válido';
    END IF;
  ELSE
    -- For non clock_in entries, ensure these fields are NULL
    NEW.work_center := NULL;
    NEW.time_type := NULL;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create or recreate triggers
CREATE TRIGGER handle_employee_creation_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_creation();

CREATE TRIGGER handle_supervisor_creation_trigger
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_creation();

CREATE TRIGGER validate_time_entry_trigger
  BEFORE INSERT OR UPDATE ON time_entries
  FOR EACH ROW
  EXECUTE FUNCTION validate_time_entry();