-- Create function to normalize delegation name
CREATE OR REPLACE FUNCTION normalize_delegation_name(p_delegation TEXT)
RETURNS delegation_enum AS $$
BEGIN
  RETURN CASE UPPER(p_delegation)
    WHEN 'MADRID' THEN 'MADRID'::delegation_enum
    WHEN 'ALAVA' THEN 'ALAVA'::delegation_enum
    WHEN 'SANTANDER' THEN 'SANTANDER'::delegation_enum
    WHEN 'SEVILLA' THEN 'SEVILLA'::delegation_enum
    WHEN 'VALLADOLID' THEN 'VALLADOLID'::delegation_enum
    WHEN 'MURCIA' THEN 'MURCIA'::delegation_enum
    WHEN 'BURGOS' THEN 'BURGOS'::delegation_enum
    WHEN 'ALICANTE' THEN 'ALICANTE'::delegation_enum
    WHEN 'CONCEPCION_LA' THEN 'CONCEPCION_LA'::delegation_enum
    WHEN 'CADIZ' THEN 'CADIZ'::delegation_enum
    WHEN 'PALENCIA' THEN 'PALENCIA'::delegation_enum
    WHEN 'CORDOBA' THEN 'CORDOBA'::delegation_enum
    ELSE NULL
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Modify employee creation function to use normalized delegation
CREATE OR REPLACE FUNCTION handle_employee_creation()
RETURNS TRIGGER AS $$
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

  -- Set default values
  NEW.country := COALESCE(NEW.country, 'España');
  NEW.timezone := COALESCE(NEW.timezone, 'Europe/Madrid');
  NEW.is_active := COALESCE(NEW.is_active, true);
  NEW.pin := COALESCE(NEW.pin, LPAD(floor(random() * 1000000)::text, 6, '0'));
  NEW.phone := COALESCE(NEW.phone, '');
  NEW.created_at := COALESCE(NEW.created_at, NOW());
  NEW.updated_at := NOW();

  -- Normalize delegation
  IF NEW.delegation IS NOT NULL THEN
    NEW.delegation := normalize_delegation_name(NEW.delegation::text);
    IF NEW.delegation IS NULL THEN
      RAISE EXCEPTION 'Delegación no válida: %', NEW.delegation;
    END IF;
  END IF;

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

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS handle_employee_creation_trigger ON employee_profiles;
CREATE TRIGGER handle_employee_creation_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_creation();