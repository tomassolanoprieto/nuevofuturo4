-- Drop existing trigger and function
DROP TRIGGER IF EXISTS validate_time_entry_trigger ON time_entries;
DROP FUNCTION IF EXISTS validate_time_entry();

-- Add work_center column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'time_entries' 
        AND column_name = 'work_center'
    ) THEN
        ALTER TABLE time_entries
        ADD COLUMN work_center work_center_enum;
    END IF;
END $$;

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

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_time_entries_work_center 
ON time_entries(work_center);

-- Create index for employee work centers
CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers 
ON employee_profiles USING gin(work_centers);