-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_employee_creation_trigger ON employee_profiles;
DROP FUNCTION IF EXISTS handle_employee_creation();

-- Create improved employee import function with better delegation handling
CREATE OR REPLACE FUNCTION handle_employee_creation()
RETURNS TRIGGER AS $$
DECLARE
  v_delegation TEXT;
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

  -- Handle work centers array
  IF NEW.work_centers IS NULL OR array_length(NEW.work_centers, 1) IS NULL THEN
    IF NEW.work_centers[1] IS NOT NULL THEN
      -- Remove any extra quotes and braces
      NEW.work_centers := ARRAY[trim(both '"' from trim(both '{}' from NEW.work_centers[1]::text))::work_center_enum];
    ELSE
      NEW.work_centers := ARRAY[]::work_center_enum[];
    END IF;
  END IF;

  -- Handle job positions array
  IF NEW.job_positions IS NULL OR array_length(NEW.job_positions, 1) IS NULL THEN
    IF NEW.job_positions[1] IS NOT NULL THEN
      -- Remove any extra quotes and braces
      NEW.job_positions := ARRAY[trim(both '"' from trim(both '{}' from NEW.job_positions[1]::text))::job_position_enum];
    ELSE
      NEW.job_positions := ARRAY[]::job_position_enum[];
    END IF;
  END IF;

  -- Handle delegation with better error handling
  IF NEW.delegation IS NOT NULL THEN
    -- Remove any extra quotes and clean the text
    v_delegation := trim(both '"' from trim(both '{}' from NEW.delegation::text));
    
    -- Map common variations to correct values
    CASE v_delegation
      WHEN 'ALAVA HAZIBIDE' THEN v_delegation := 'Álava';
      WHEN 'ALAVA' THEN v_delegation := 'Álava';
      WHEN 'GUIPUZCOA' THEN v_delegation := 'Guipúzcoa';
      WHEN 'MALAGA' THEN v_delegation := 'Málaga';
      WHEN 'CADIZ' THEN v_delegation := 'Cádiz';
      WHEN 'CORDOBA' THEN v_delegation := 'Córdoba';
      ELSE v_delegation := initcap(v_delegation);
    END CASE;

    -- Try to cast to delegation_enum
    BEGIN
      NEW.delegation := v_delegation::delegation_enum;
    EXCEPTION
      WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'Delegación no válida: %. Valores permitidos: Santander, Madrid, Málaga, Álava, Guipúzcoa, Burgos, Palencia, Valladolid, Alicante, Murcia, Cádiz, Córdoba, Campo Gibraltar, Sevilla', v_delegation;
    END;
  END IF;

  -- Convert seniority_date from text if needed
  IF NEW.seniority_date IS NULL AND NEW.employee_id IS NOT NULL THEN
    BEGIN
      NEW.seniority_date := TO_DATE(NEW.employee_id, 'YYYY-MM-DD');
    EXCEPTION
      WHEN OTHERS THEN
        -- If conversion fails, leave as NULL
        NULL;
    END;
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
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'El email ya existe';
  WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'Valor no válido para centro de trabajo o puesto';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al crear empleado: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for employee creation
CREATE TRIGGER handle_employee_creation_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_creation();