-- Drop existing policies first
DROP POLICY IF EXISTS "supervisor_profiles_access" ON supervisor_profiles;
DROP POLICY IF EXISTS "supervisor_employee_access" ON employee_profiles;

-- Create improved supervisor creation function with unique name
CREATE OR REPLACE FUNCTION handle_supervisor_creation_v2()
RETURNS TRIGGER AS $$
BEGIN
  -- Generate new UUID for the supervisor
  NEW.id := gen_random_uuid();

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

  -- Validate supervisor type and assignments
  IF NEW.supervisor_type = 'center' AND array_length(NEW.work_centers, 1) IS NULL THEN
    RAISE EXCEPTION 'Work centers are required for center supervisors';
  END IF;

  IF NEW.supervisor_type = 'delegation' AND array_length(NEW.delegations, 1) IS NULL THEN
    RAISE EXCEPTION 'Delegations are required for delegation supervisors';
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'Centro de trabajo o delegación no válido';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al crear supervisor: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Create trigger with unique name
CREATE TRIGGER handle_supervisor_creation_trigger_v2
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_creation_v2();

-- Create policy with unique name
CREATE POLICY "supervisor_profiles_access_v2"
  ON supervisor_profiles
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create policy for supervisor access to employee data with unique name
CREATE POLICY "supervisor_employee_access_v2"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = employee_profiles.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND employee_profiles.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND employee_profiles.delegation = ANY(sp.delegations))
      )
    )
  );

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_company_id ON supervisor_profiles(company_id);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_is_active ON supervisor_profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_work_centers ON supervisor_profiles USING gin(work_centers);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_delegations ON supervisor_profiles USING gin(delegations);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_supervisor_type ON supervisor_profiles(supervisor_type);