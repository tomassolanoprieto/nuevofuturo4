-- First drop all dependent policies
DROP POLICY IF EXISTS "Users can update planner requests" ON planner_requests;
DROP POLICY IF EXISTS "Users can update time requests" ON time_requests;
DROP POLICY IF EXISTS "Users can view planner requests" ON planner_requests;
DROP POLICY IF EXISTS "Users can view time requests" ON time_requests;
DROP POLICY IF EXISTS "employee_access_policy" ON employee_profiles;
DROP POLICY IF EXISTS "supervisor_calendar_events_access" ON calendar_events;
DROP POLICY IF EXISTS "supervisor_time_entries_access" ON time_entries;
DROP POLICY IF EXISTS "supervisor_time_requests_access" ON time_requests;
DROP POLICY IF EXISTS "supervisor_vacation_requests_access" ON planner_requests;
DROP POLICY IF EXISTS "time_entries_access" ON time_entries;
DROP POLICY IF EXISTS "employee_profile_access" ON employee_profiles;

-- Temporarily disable triggers
DROP TRIGGER IF EXISTS validate_time_entry_trigger ON time_entries;
DROP TRIGGER IF EXISTS update_daily_hours_trigger ON time_entries;

-- Create new work_center_enum type
DROP TYPE IF EXISTS work_center_enum_new CASCADE;
CREATE TYPE work_center_enum_new AS ENUM (
  'MADRID HOGARES DE EMANCIPACION V. DEL PARDILLO',
  'MADRID CUEVAS DE ALMANZORA',
  'MADRID OFICINA',
  'MADRID ALCOBENDAS',
  'MADRID JOSE DE PASAMONTE',
  'MADRID VALDEBERNARDO',
  'MADRID MIGUEL HERNANDEZ',
  'MADRID GABRIEL USERA',
  'MADRID IBIZA',
  'MADRID DIRECTORES DE CENTRO',
  'MADRID HUMANITARIAS',
  'MADRID VIRGEN DEL PUIG',
  'MADRID ALMACEN',
  'MADRID PASEO EXTREMADURA',
  'MADRID HOGARES DE EMANCIPACION SANTA CLARA',
  'MADRID ARROYO DE LAS PILILLAS',
  'MADRID AVDA. DE AMERICA',
  'MADRID CENTRO DE DIA CARMEN HERRERO',
  'MADRID HOGARES DE EMANCIPACION BOCANGEL'
);

-- Add new columns
ALTER TABLE employee_profiles 
ADD COLUMN IF NOT EXISTS work_centers_new work_center_enum_new[] DEFAULT '{}';

ALTER TABLE supervisor_profiles 
ADD COLUMN IF NOT EXISTS work_centers_new work_center_enum_new[] DEFAULT '{}';

ALTER TABLE time_entries
ADD COLUMN IF NOT EXISTS work_center_new work_center_enum_new;

-- Create mapping function for work centers
CREATE OR REPLACE FUNCTION map_work_center(old_value text)
RETURNS work_center_enum_new AS $$
BEGIN
  CASE old_value
    WHEN 'MADRID AVDA DE AMERICA' THEN RETURN 'MADRID AVDA. DE AMERICA';
    WHEN 'Ventas' THEN RETURN 'MADRID IBIZA';
    WHEN 'Ibiza' THEN RETURN 'MADRID IBIZA';
    WHEN 'Pilillas' THEN RETURN 'MADRID ARROYO DE LAS PILILLAS';
    WHEN 'Pasamonte' THEN RETURN 'MADRID JOSE DE PASAMONTE';
    ELSE 
      -- Try to match with MADRID prefix
      BEGIN
        RETURN ('MADRID ' || old_value)::work_center_enum_new;
      EXCEPTION
        WHEN invalid_text_representation THEN
          -- Try direct cast
          BEGIN
            RETURN old_value::work_center_enum_new;
          EXCEPTION
            WHEN invalid_text_representation THEN
              RETURN NULL;
          END;
      END;
  END CASE;
END;
$$ LANGUAGE plpgsql;

-- Update data with mapping
UPDATE employee_profiles e
SET work_centers_new = ARRAY(
  SELECT DISTINCT map_work_center(unnest.value::text)
  FROM unnest(e.work_centers) AS unnest(value)
  WHERE map_work_center(unnest.value::text) IS NOT NULL
)
WHERE work_centers IS NOT NULL;

UPDATE supervisor_profiles s
SET work_centers_new = ARRAY(
  SELECT DISTINCT map_work_center(unnest.value::text)
  FROM unnest(s.work_centers) AS unnest(value)
  WHERE map_work_center(unnest.value::text) IS NOT NULL
)
WHERE work_centers IS NOT NULL;

UPDATE time_entries t
SET work_center_new = map_work_center(t.work_center::text)
WHERE work_center IS NOT NULL;

-- Drop old columns and type CASCADE to handle dependencies
ALTER TABLE employee_profiles DROP COLUMN IF EXISTS work_centers CASCADE;
ALTER TABLE supervisor_profiles DROP COLUMN IF EXISTS work_centers CASCADE;
ALTER TABLE time_entries DROP COLUMN IF EXISTS work_center CASCADE;
DROP TYPE IF EXISTS work_center_enum CASCADE;

-- Rename columns and type
ALTER TABLE employee_profiles RENAME COLUMN work_centers_new TO work_centers;
ALTER TABLE supervisor_profiles RENAME COLUMN work_centers_new TO work_centers;
ALTER TABLE time_entries RENAME COLUMN work_center_new TO work_center;
ALTER TYPE work_center_enum_new RENAME TO work_center_enum;

-- Drop mapping function
DROP FUNCTION map_work_center(text);

-- Recreate indexes
CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers 
ON employee_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_work_centers 
ON supervisor_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_time_entries_work_center 
ON time_entries(work_center);

-- Recreate all policies
CREATE POLICY "employee_profile_access"
  ON employee_profiles
  FOR ALL
  TO authenticated
  USING (
    id = auth.uid() OR
    company_id = auth.uid() OR
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
  )
  WITH CHECK (
    id = auth.uid() OR
    company_id = auth.uid()
  );

CREATE POLICY "time_entries_access"
  ON time_entries
  FOR ALL
  TO authenticated
  USING (
    employee_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_entries.employee_id
      AND ep.company_id = auth.uid()
    )
  );

CREATE POLICY "supervisor_time_entries_access"
  ON time_entries
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      JOIN employee_profiles ep ON ep.id = time_entries.employee_id
      WHERE sp.id = auth.uid()
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  );

-- Recreate time entry validation
CREATE OR REPLACE FUNCTION validate_time_entry()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.entry_type = 'clock_in' THEN
    IF NEW.work_center IS NULL THEN
      RAISE EXCEPTION 'El centro de trabajo es obligatorio para los fichajes de entrada';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM employee_profiles
      WHERE id = NEW.employee_id
      AND NEW.work_center = ANY(work_centers)
    ) THEN
      RAISE EXCEPTION 'Centro de trabajo no válido para este empleado';
    END IF;

    IF NEW.time_type IS NULL THEN
      RAISE EXCEPTION 'El tipo de fichaje es obligatorio para los fichajes de entrada';
    END IF;
  ELSE
    NEW.work_center := NULL;
    NEW.time_type := NULL;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate triggers
CREATE TRIGGER validate_time_entry_trigger
  BEFORE INSERT OR UPDATE ON time_entries
  FOR EACH ROW
  EXECUTE FUNCTION validate_time_entry();