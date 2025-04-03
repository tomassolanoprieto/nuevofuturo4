-- Drop existing trigger and function
DROP TRIGGER IF EXISTS validate_time_entry_trigger ON time_entries;
DROP FUNCTION IF EXISTS validate_time_entry();

-- Create function to get date from timestamp (IMMUTABLE)
CREATE OR REPLACE FUNCTION get_date_from_timestamp(ts timestamptz)
RETURNS date AS $$
BEGIN
  RETURN ts::date;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create improved time entry validation function
CREATE OR REPLACE FUNCTION validate_time_entry()
RETURNS TRIGGER AS $$
DECLARE
  v_last_entry RECORD;
  v_employee_profile RECORD;
  v_open_entry RECORD;
  v_clock_in_entry RECORD;
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

  -- Get last entry for this employee on the same day
  SELECT * INTO v_last_entry
  FROM time_entries
  WHERE employee_id = NEW.employee_id
  AND get_date_from_timestamp(timestamp) = get_date_from_timestamp(NEW.timestamp)
  ORDER BY timestamp DESC
  LIMIT 1;

  -- Find any open entry (clock_in or break_end without corresponding break_start/clock_out)
  WITH entry_pairs AS (
    SELECT 
      t1.id,
      t1.entry_type as start_type,
      t1.timestamp as start_time,
      t1.work_center,
      t1.time_type,
      MIN(t2.timestamp) as end_time
    FROM time_entries t1
    LEFT JOIN time_entries t2 ON t1.employee_id = t2.employee_id
      AND t2.timestamp > t1.timestamp
      AND (
        (t1.entry_type = 'clock_in' AND t2.entry_type IN ('break_start', 'clock_out')) OR
        (t1.entry_type = 'break_end' AND t2.entry_type IN ('break_start', 'clock_out'))
      )
    WHERE t1.employee_id = NEW.employee_id
    AND t1.entry_type IN ('clock_in', 'break_end')
    AND get_date_from_timestamp(t1.timestamp) = get_date_from_timestamp(NEW.timestamp)
    GROUP BY t1.id, t1.entry_type, t1.timestamp, t1.work_center, t1.time_type
  )
  SELECT * INTO v_open_entry
  FROM entry_pairs
  WHERE end_time IS NULL
  ORDER BY start_time DESC
  LIMIT 1;

  -- Get the original clock_in entry for this sequence
  SELECT * INTO v_clock_in_entry
  FROM time_entries
  WHERE employee_id = NEW.employee_id
  AND entry_type = 'clock_in'
  AND get_date_from_timestamp(timestamp) = get_date_from_timestamp(NEW.timestamp)
  AND timestamp <= COALESCE(NEW.timestamp, now())
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

    -- Handle work center validation
    IF array_length(v_employee_profile.work_centers, 1) = 1 THEN
      -- If employee has only one work center, use it automatically
      NEW.work_center := v_employee_profile.work_centers[1];
    ELSIF NEW.work_center IS NULL THEN
      -- For multiple work centers, one must be specified
      RAISE EXCEPTION 'El centro de trabajo es obligatorio para los fichajes de entrada';
    ELSIF NOT (NEW.work_center = ANY(v_employee_profile.work_centers)) THEN
      -- Validate that the specified work center is valid for this employee
      RAISE EXCEPTION 'Centro de trabajo no válido para este empleado';
    END IF;

    -- Check if there's already an open entry
    IF v_open_entry.id IS NOT NULL THEN
      RAISE EXCEPTION 'Ya existe un fichaje de entrada activo';
    END IF;
  ELSE
    -- For non clock_in entries, copy work_center and time_type from the original clock_in
    IF v_clock_in_entry.id IS NOT NULL THEN
      NEW.work_center := v_clock_in_entry.work_center;
      NEW.time_type := v_clock_in_entry.time_type;
    END IF;

    -- Validate sequence based on last entry
    CASE NEW.entry_type
      WHEN 'break_start' THEN
        IF v_open_entry.id IS NULL THEN
          RAISE EXCEPTION 'Debe existir una entrada activa antes de iniciar una pausa';
        END IF;
      WHEN 'break_end' THEN
        IF v_last_entry.entry_type != 'break_start' THEN
          RAISE EXCEPTION 'Debe existir una pausa activa antes de finalizarla';
        END IF;
      WHEN 'clock_out' THEN
        IF v_open_entry.id IS NULL THEN
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

-- Create indexes for better performance using IMMUTABLE function
CREATE INDEX IF NOT EXISTS idx_time_entries_employee_timestamp 
ON time_entries(employee_id, timestamp);

CREATE INDEX IF NOT EXISTS idx_time_entries_employee_date
ON time_entries(employee_id, get_date_from_timestamp(timestamp));