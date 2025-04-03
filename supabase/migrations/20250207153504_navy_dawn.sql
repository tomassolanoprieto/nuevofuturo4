-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_employee_creation_trigger ON employee_profiles;
DROP FUNCTION IF EXISTS handle_employee_creation();

-- Create improved employee import function with better array handling
CREATE OR REPLACE FUNCTION handle_employee_creation()
RETURNS TRIGGER AS $$
DECLARE
  v_work_center work_center_enum;
  v_job_position job_position_enum;
BEGIN
  -- Generate new UUID for the employee
  NEW.id := gen_random_uuid();

  -- Set default values
  NEW.country := COALESCE(NEW.country, 'España');
  NEW.timezone := COALESCE(NEW.timezone, 'Europe/Madrid');
  NEW.is_active := COALESCE(NEW.is_active, true);
  NEW.pin := COALESCE(NEW.pin, LPAD(floor(random() * 1000000)::text, 6, '0'));

  -- Handle work centers array
  IF NEW.work_centers IS NULL OR array_length(NEW.work_centers, 1) IS NULL THEN
    -- Try to convert single value to array if provided
    IF NEW.work_centers[1] IS NOT NULL THEN
      -- Remove any extra quotes and braces
      v_work_center := trim(both '"' from trim(both '{}' from NEW.work_centers[1]::text))::work_center_enum;
      NEW.work_centers := ARRAY[v_work_center];
    ELSE
      NEW.work_centers := ARRAY[]::work_center_enum[];
    END IF;
  END IF;

  -- Handle job positions array
  IF NEW.job_positions IS NULL OR array_length(NEW.job_positions, 1) IS NULL THEN
    -- Try to convert single value to array if provided
    IF NEW.job_positions[1] IS NOT NULL THEN
      -- Remove any extra quotes and braces
      v_job_position := trim(both '"' from trim(both '{}' from NEW.job_positions[1]::text))::job_position_enum;
      NEW.job_positions := ARRAY[v_job_position];
    ELSE
      NEW.job_positions := ARRAY[]::job_position_enum[];
    END IF;
  END IF;

  -- Handle delegation (ensure proper case)
  IF NEW.delegation IS NOT NULL THEN
    NEW.delegation := initcap(NEW.delegation)::delegation_enum;
  END IF;

  -- Create auth user
  INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    role
  )
  VALUES (
    NEW.id,
    NEW.email,
    crypt(NEW.pin, gen_salt('bf')),
    NOW(),
    'authenticated'
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
CREATE POLICY "employee_profiles_access_policy_v6"
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