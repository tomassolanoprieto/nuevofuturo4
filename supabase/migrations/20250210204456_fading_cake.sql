-- First drop the trigger that depends on the function
DROP TRIGGER IF EXISTS validate_time_entry_trigger ON time_entries CASCADE;

-- Now we can safely drop the functions
DROP FUNCTION IF EXISTS verify_employee_credentials(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS validate_time_entry() CASCADE;

-- Create improved employee authentication function
CREATE OR REPLACE FUNCTION verify_employee_credentials(
  p_email TEXT,
  p_pin TEXT
)
RETURNS TABLE (
  id UUID,
  fiscal_name TEXT,
  email TEXT,
  work_centers work_center_enum[],
  delegation delegation_enum,
  is_active BOOLEAN,
  company_id UUID
) AS $$
BEGIN
  -- Validate input
  IF p_email IS NULL OR p_pin IS NULL THEN
    RAISE EXCEPTION 'Email y PIN son obligatorios';
  END IF;

  -- Return employee info if credentials match
  RETURN QUERY
  SELECT 
    ep.id,
    ep.fiscal_name,
    ep.email,
    ep.work_centers,
    ep.delegation,
    ep.is_active,
    ep.company_id
  FROM employee_profiles ep
  WHERE ep.email = p_email 
  AND ep.pin = p_pin
  AND ep.is_active = true;

  -- If no rows returned, credentials are invalid
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Credenciales inválidas';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create improved time entry validation function
CREATE OR REPLACE FUNCTION validate_time_entry()
RETURNS TRIGGER AS $$
DECLARE
  v_last_entry RECORD;
  v_employee_profile RECORD;
BEGIN
  -- Get employee profile
  SELECT * INTO v_employee_profile
  FROM employee_profiles
  WHERE id = NEW.employee_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Empleado no encontrado';
  END IF;

  IF NOT v_employee_profile.is_active THEN
    RAISE EXCEPTION 'Empleado inactivo';
  END IF;

  -- Get last entry
  SELECT * INTO v_last_entry
  FROM time_entries
  WHERE employee_id = NEW.employee_id
  ORDER BY timestamp DESC
  LIMIT 1;

  -- Validate entry_type
  IF NEW.entry_type NOT IN ('clock_in', 'break_start', 'break_end', 'clock_out') THEN
    RAISE EXCEPTION 'Tipo de entrada no válido';
  END IF;

  -- Special validations for clock_in
  IF NEW.entry_type = 'clock_in' THEN
    -- Validate time_type
    IF NEW.time_type IS NULL THEN
      RAISE EXCEPTION 'El tipo de fichaje es obligatorio para los fichajes de entrada';
    END IF;

    IF NEW.time_type NOT IN ('turno', 'coordinacion', 'formacion', 'sustitucion', 'otros') THEN
      RAISE EXCEPTION 'Tipo de fichaje no válido';
    END IF;

    -- If employee has only one work center, use it automatically
    IF array_length(v_employee_profile.work_centers, 1) = 1 THEN
      NEW.work_center := v_employee_profile.work_centers[1];
    END IF;

    -- Check if there's already an open entry
    IF v_last_entry.entry_type IN ('clock_in', 'break_end') THEN
      RAISE EXCEPTION 'Ya existe un fichaje de entrada activo';
    END IF;
  ELSE
    -- For non clock_in entries, these fields should be NULL
    NEW.work_center := NULL;
    NEW.time_type := NULL;

    -- Validate sequence based on last entry
    CASE NEW.entry_type
      WHEN 'break_start' THEN
        IF v_last_entry.entry_type NOT IN ('clock_in', 'break_end') THEN
          RAISE EXCEPTION 'Debe existir una entrada activa antes de iniciar una pausa';
        END IF;
      WHEN 'break_end' THEN
        IF v_last_entry.entry_type != 'break_start' THEN
          RAISE EXCEPTION 'Debe existir una pausa activa antes de finalizarla';
        END IF;
      WHEN 'clock_out' THEN
        IF v_last_entry.entry_type NOT IN ('clock_in', 'break_end') THEN
          RAISE EXCEPTION 'Debe existir una entrada activa antes de registrar una salida';
        END IF;
    END CASE;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for time entry validation
CREATE TRIGGER validate_time_entry_trigger
  BEFORE INSERT OR UPDATE ON time_entries
  FOR EACH ROW
  EXECUTE FUNCTION validate_time_entry();

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_email_pin_active 
ON employee_profiles(email, pin, is_active);

CREATE INDEX IF NOT EXISTS idx_time_entries_employee_timestamp 
ON time_entries(employee_id, timestamp);