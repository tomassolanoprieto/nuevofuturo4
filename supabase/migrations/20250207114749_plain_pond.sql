-- First drop any existing ID constraints
ALTER TABLE employee_profiles 
DROP CONSTRAINT IF EXISTS employee_profiles_pkey CASCADE;

-- Recreate the primary key with auto-generation
ALTER TABLE employee_profiles
ALTER COLUMN id SET DEFAULT gen_random_uuid(),
ADD PRIMARY KEY (id);

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_employee_import_trigger ON employee_profiles;
DROP FUNCTION IF EXISTS handle_employee_import();

-- Create simplified employee import function that doesn't set ID
CREATE OR REPLACE FUNCTION handle_employee_import()
RETURNS TRIGGER AS $$
DECLARE
  v_instance_id UUID;
BEGIN
  -- Let Postgres generate the ID
  -- NEW.id will be automatically set by the DEFAULT constraint

  -- Get instance_id from an existing user
  SELECT instance_id INTO v_instance_id 
  FROM auth.users 
  WHERE instance_id IS NOT NULL 
  LIMIT 1;

  -- Create auth user with the ID that was auto-generated
  INSERT INTO auth.users (
    id,
    instance_id,
    email,
    encrypted_password,
    role,
    aud
  )
  VALUES (
    NEW.id, -- Use the auto-generated ID
    v_instance_id,
    NEW.email,
    crypt(COALESCE(NEW.pin, LPAD(floor(random() * 1000000)::text, 6, '0')), gen_salt('bf')),
    'authenticated',
    'authenticated'
  );

  -- Set default values for employee profile
  NEW.country := COALESCE(NEW.country, 'España');
  NEW.timezone := COALESCE(NEW.timezone, 'Europe/Madrid');
  NEW.is_active := COALESCE(NEW.is_active, true);
  NEW.work_centers := COALESCE(NEW.work_centers, ARRAY[]::work_center_enum[]);
  NEW.job_positions := COALESCE(NEW.job_positions, ARRAY[]::job_position_enum[]);

  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'El email ya existe';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al crear empleado: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger that runs BEFORE INSERT
CREATE TRIGGER handle_employee_import_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_employee_import();