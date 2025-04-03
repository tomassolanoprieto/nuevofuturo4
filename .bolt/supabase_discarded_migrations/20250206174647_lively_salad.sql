-- First drop all dependent policies
DROP POLICY IF EXISTS "Users can update planner requests" ON planner_requests;
DROP POLICY IF EXISTS "Users can update time requests" ON time_requests;
DROP POLICY IF EXISTS "Users can view planner requests" ON planner_requests;
DROP POLICY IF EXISTS "Users can view time requests" ON time_requests;
DROP POLICY IF EXISTS "supervisor_calendar_events_access" ON calendar_events;
DROP POLICY IF EXISTS "supervisor_time_entries_access" ON time_entries;
DROP POLICY IF EXISTS "supervisor_time_requests_access" ON time_requests;
DROP POLICY IF EXISTS "supervisor_vacation_requests_access" ON planner_requests;
DROP POLICY IF EXISTS "time_entries_access" ON time_entries;
DROP POLICY IF EXISTS "employee_access_policy" ON employee_profiles;
DROP POLICY IF EXISTS "daily_work_hours_access" ON daily_work_hours;

-- Create new work_center_enum type with new values
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
  'MADRID AVDA DE AMERICA',
  'MADRID CENTRO DE DIA CARMEN HERRERO',
  'MADRID HOGARES DE EMANCIPACION BOCANGEL'
);

-- Create temporary columns with new type
ALTER TABLE employee_profiles 
ADD COLUMN work_centers_new work_center_enum_new[] DEFAULT '{}';

ALTER TABLE supervisor_profiles 
ADD COLUMN work_centers_new work_center_enum_new[] DEFAULT '{}';

ALTER TABLE daily_work_hours
ADD COLUMN work_centers_new work_center_enum_new[] DEFAULT '{}',
ADD COLUMN assigned_centers_new work_center_enum_new[] DEFAULT '{}';

ALTER TABLE time_entries
ADD COLUMN work_center_new work_center_enum_new;

-- Create function to convert old values to new
CREATE OR REPLACE FUNCTION convert_work_center(old_value text)
RETURNS work_center_enum_new AS $$
BEGIN
  RETURN old_value::work_center_enum_new;
EXCEPTION
  WHEN invalid_text_representation THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Update data in temporary columns
UPDATE employee_profiles
SET work_centers_new = ARRAY(
  SELECT convert_work_center(value::text)
  FROM unnest(work_centers) AS value
  WHERE convert_work_center(value::text) IS NOT NULL
);

UPDATE supervisor_profiles
SET work_centers_new = ARRAY(
  SELECT convert_work_center(value::text)
  FROM unnest(work_centers) AS value
  WHERE convert_work_center(value::text) IS NOT NULL
);

UPDATE daily_work_hours
SET work_centers_new = ARRAY(
  SELECT convert_work_center(value::text)
  FROM unnest(work_centers) AS value
  WHERE convert_work_center(value::text) IS NOT NULL
),
assigned_centers_new = ARRAY(
  SELECT convert_work_center(value::text)
  FROM unnest(assigned_centers) AS value
  WHERE convert_work_center(value::text) IS NOT NULL
);

UPDATE time_entries
SET work_center_new = convert_work_center(work_center::text);

-- Drop old columns CASCADE to remove dependencies
ALTER TABLE employee_profiles DROP COLUMN work_centers CASCADE;
ALTER TABLE supervisor_profiles DROP COLUMN work_centers CASCADE;
ALTER TABLE daily_work_hours DROP COLUMN work_centers CASCADE;
ALTER TABLE daily_work_hours DROP COLUMN assigned_centers CASCADE;
ALTER TABLE time_entries DROP COLUMN work_center CASCADE;

-- Set NOT NULL constraints
ALTER TABLE employee_profiles ALTER COLUMN work_centers_new SET NOT NULL;
ALTER TABLE supervisor_profiles ALTER COLUMN work_centers_new SET NOT NULL;
ALTER TABLE daily_work_hours ALTER COLUMN work_centers_new SET NOT NULL;
ALTER TABLE daily_work_hours ALTER COLUMN assigned_centers_new SET NOT NULL;

-- Rename new columns
ALTER TABLE employee_profiles RENAME COLUMN work_centers_new TO work_centers;
ALTER TABLE supervisor_profiles RENAME COLUMN work_centers_new TO work_centers;
ALTER TABLE daily_work_hours RENAME COLUMN work_centers_new TO work_centers;
ALTER TABLE daily_work_hours RENAME COLUMN assigned_centers_new TO assigned_centers;
ALTER TABLE time_entries RENAME COLUMN work_center_new TO work_center;

-- Drop old type and rename new one
DROP TYPE work_center_enum CASCADE;
ALTER TYPE work_center_enum_new RENAME TO work_center_enum;

-- Drop conversion function
DROP FUNCTION convert_work_center(text);

-- Recreate indexes
CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers 
ON employee_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_work_centers 
ON supervisor_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_daily_work_hours_work_centers 
ON daily_work_hours USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_daily_work_hours_assigned_centers 
ON daily_work_hours USING gin(assigned_centers);

CREATE INDEX IF NOT EXISTS idx_time_entries_work_center 
ON time_entries(work_center);

-- Recreate policies
CREATE POLICY "employee_access_policy"
  ON employee_profiles
  FOR SELECT
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
  );

CREATE POLICY "daily_work_hours_access"
  ON daily_work_hours
  FOR ALL
  TO authenticated
  USING (
    employee_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = daily_work_hours.employee_id
      AND ep.company_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      JOIN employee_profiles ep ON ep.id = daily_work_hours.employee_id
      WHERE sp.id = auth.uid()
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  );

-- Recreate other necessary policies...