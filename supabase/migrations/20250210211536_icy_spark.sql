-- Drop existing policies if they exist
DROP POLICY IF EXISTS "time_entries_access_v6" ON time_entries;
DROP POLICY IF EXISTS "time_entries_access_v5" ON time_entries;
DROP POLICY IF EXISTS "time_entries_access_v4" ON time_entries;
DROP POLICY IF EXISTS "time_entries_access_v3" ON time_entries;

-- Create comprehensive policy for time entries
CREATE POLICY "time_entries_access_v7"
  ON time_entries
  FOR ALL
  TO authenticated
  USING (
    -- Employee can access their own entries
    employee_id = auth.uid() OR
    -- Company can access their employees' entries
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_entries.employee_id
      AND ep.company_id = auth.uid()
    )
  )
  WITH CHECK (
    -- Employee can modify their own entries
    employee_id = auth.uid() OR
    -- Company can modify their employees' entries
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_entries.employee_id
      AND ep.company_id = auth.uid()
    )
  );

-- Create function to validate time entry
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
    ELSIF NEW.work_center IS NULL THEN
      RAISE EXCEPTION 'El centro de trabajo es obligatorio para los fichajes de entrada';
    ELSIF NOT (NEW.work_center = ANY(v_employee_profile.work_centers)) THEN
      RAISE EXCEPTION 'Centro de trabajo no válido para este empleado';
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
DROP TRIGGER IF EXISTS validate_time_entry_trigger ON time_entries;
CREATE TRIGGER validate_time_entry_trigger
  BEFORE INSERT OR UPDATE ON time_entries
  FOR EACH ROW
  EXECUTE FUNCTION validate_time_entry();

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_time_entries_employee_id 
ON time_entries(employee_id);

CREATE INDEX IF NOT EXISTS idx_time_entries_work_center 
ON time_entries(work_center);

CREATE INDEX IF NOT EXISTS idx_time_entries_timestamp 
ON time_entries(timestamp);