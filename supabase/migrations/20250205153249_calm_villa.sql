-- Drop existing trigger and function
DROP TRIGGER IF EXISTS validate_time_entry_work_center_trigger ON time_entries;
DROP FUNCTION IF EXISTS validate_time_entry_work_center();

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

  -- Validate timestamp
  IF NEW.timestamp IS NULL THEN
    RAISE EXCEPTION 'La fecha y hora son obligatorias';
  END IF;

  -- Validate entry_type
  IF NEW.entry_type NOT IN ('clock_in', 'break_start', 'break_end', 'clock_out') THEN
    RAISE EXCEPTION 'Tipo de entrada no válido';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for time entry validation
CREATE TRIGGER validate_time_entry_trigger
  BEFORE INSERT OR UPDATE ON time_entries
  FOR EACH ROW
  EXECUTE FUNCTION validate_time_entry();

-- Update existing entries to ensure data consistency
UPDATE time_entries
SET 
  work_center = NULL,
  time_type = NULL
WHERE entry_type != 'clock_in';