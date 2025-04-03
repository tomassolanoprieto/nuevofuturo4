-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_employee_creation_trigger ON employee_profiles;
DROP FUNCTION IF EXISTS handle_employee_creation();

-- Create improved employee import function
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

  -- Handle delegation (ensure proper case)
  IF NEW.delegation IS NOT NULL THEN
    NEW.delegation := initcap(NEW.delegation)::delegation_enum;
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
    RAISE EXCEPTION 'Valor no válido para centro de trabajo, puesto o delegación';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al crear empleado: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for employee creation
CREATE TRIGGER handle_employee_creation_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_creation();

-- Create policy that allows all operations
CREATE POLICY "employee_profiles_access_policy_v9"
  ON employee_profiles
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_email ON employee_profiles(email);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_company_id ON employee_profiles(company_id);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_is_active ON employee_profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers ON employee_profiles USING gin(work_centers);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_job_positions ON employee_profiles USING gin(job_positions);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation ON employee_profiles(delegation);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_employee_id ON employee_profiles(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_seniority_date ON employee_profiles(seniority_date);