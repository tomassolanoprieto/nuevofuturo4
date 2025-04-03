-- Drop existing trigger and function
DROP TRIGGER IF EXISTS validate_time_entry_trigger ON time_entries;
DROP FUNCTION IF EXISTS validate_time_entry();

-- Create improved time entry validation function
CREATE OR REPLACE FUNCTION validate_time_entry()
RETURNS TRIGGER AS $$
BEGIN
  -- Validate timestamp
  IF NEW.timestamp IS NULL THEN
    RAISE EXCEPTION 'La fecha y hora son obligatorias';
  END IF;

  -- Validate entry_type
  IF NEW.entry_type NOT IN ('clock_in', 'break_start', 'break_end', 'clock_out') THEN
    RAISE EXCEPTION 'Tipo de entrada no válido';
  END IF;

  -- Special validations for clock_in
  IF NEW.entry_type = 'clock_in' THEN
    -- Validate work_center
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

    -- Validate time_type
    IF NEW.time_type IS NULL THEN
      RAISE EXCEPTION 'El tipo de fichaje es obligatorio para los fichajes de entrada';
    END IF;

    -- Validate time_type value
    IF NEW.time_type NOT IN ('turno', 'coordinacion', 'formacion', 'sustitucion', 'otros') THEN
      RAISE EXCEPTION 'Tipo de fichaje no válido';
    END IF;

    -- Check if there's already an open entry
    IF EXISTS (
      SELECT 1 
      FROM time_entries 
      WHERE employee_id = NEW.employee_id
      AND entry_type IN ('clock_in', 'break_end')
      AND NOT EXISTS (
        SELECT 1 
        FROM time_entries 
        WHERE employee_id = NEW.employee_id
        AND entry_type IN ('break_start', 'clock_out')
        AND timestamp > time_entries.timestamp
      )
    ) THEN
      RAISE EXCEPTION 'Ya existe un fichaje de entrada activo';
    END IF;
  ELSE
    -- For non clock_in entries, these fields should be NULL
    NEW.work_center := NULL;
    NEW.time_type := NULL;

    -- Validate sequence
    CASE NEW.entry_type
      WHEN 'break_start' THEN
        IF NOT EXISTS (
          SELECT 1 
          FROM time_entries 
          WHERE employee_id = NEW.employee_id
          AND entry_type = 'clock_in'
          AND timestamp < NEW.timestamp
          AND NOT EXISTS (
            SELECT 1 
            FROM time_entries 
            WHERE employee_id = NEW.employee_id
            AND entry_type IN ('break_start', 'clock_out')
            AND timestamp > time_entries.timestamp
            AND timestamp < NEW.timestamp
          )
        ) THEN
          RAISE EXCEPTION 'Debe existir una entrada activa antes de iniciar una pausa';
        END IF;
      WHEN 'break_end' THEN
        IF NOT EXISTS (
          SELECT 1 
          FROM time_entries 
          WHERE employee_id = NEW.employee_id
          AND entry_type = 'break_start'
          AND timestamp < NEW.timestamp
          AND NOT EXISTS (
            SELECT 1 
            FROM time_entries 
            WHERE employee_id = NEW.employee_id
            AND entry_type IN ('break_end', 'clock_out')
            AND timestamp > time_entries.timestamp
            AND timestamp < NEW.timestamp
          )
        ) THEN
          RAISE EXCEPTION 'Debe existir una pausa activa antes de finalizarla';
        END IF;
      WHEN 'clock_out' THEN
        IF NOT EXISTS (
          SELECT 1 
          FROM time_entries 
          WHERE employee_id = NEW.employee_id
          AND entry_type IN ('clock_in', 'break_end')
          AND timestamp < NEW.timestamp
          AND NOT EXISTS (
            SELECT 1 
            FROM time_entries 
            WHERE employee_id = NEW.employee_id
            AND entry_type IN ('break_start', 'clock_out')
            AND timestamp > time_entries.timestamp
            AND timestamp < NEW.timestamp
          )
        ) THEN
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

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_time_entries_employee_timestamp 
ON time_entries(employee_id, timestamp);