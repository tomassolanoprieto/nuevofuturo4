-- First create the new enum type
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

-- Add temporary columns
ALTER TABLE employee_profiles 
ADD COLUMN work_centers_new work_center_enum_new[] DEFAULT '{}';

ALTER TABLE supervisor_profiles 
ADD COLUMN work_centers_new work_center_enum_new[] DEFAULT '{}';

ALTER TABLE time_entries
ADD COLUMN work_center_new work_center_enum_new;

-- Create mapping function
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

-- Update data in new columns
UPDATE employee_profiles e
SET work_centers_new = ARRAY(
  SELECT DISTINCT map_work_center(unnest.value::text)
  FROM unnest(e.work_centers) AS unnest(value)
  WHERE map_work_center(unnest.value::text) IS NOT NULL
);

UPDATE supervisor_profiles s
SET work_centers_new = ARRAY(
  SELECT DISTINCT map_work_center(unnest.value::text)
  FROM unnest(s.work_centers) AS unnest(value)
  WHERE map_work_center(unnest.value::text) IS NOT NULL
);

UPDATE time_entries t
SET work_center_new = map_work_center(t.work_center::text)
WHERE work_center IS NOT NULL;

-- Create new policies that use the new columns
CREATE POLICY "employee_access_policy_new"
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
        (sp.supervisor_type = 'center' AND employee_profiles.work_centers_new && sp.work_centers_new) OR
        (sp.supervisor_type = 'delegation' AND employee_profiles.delegation = ANY(sp.delegations))
      )
    )
  )
  WITH CHECK (
    id = auth.uid() OR
    company_id = auth.uid()
  );

-- Create new indexes for the new columns
CREATE INDEX idx_employee_profiles_work_centers_new 
ON employee_profiles USING gin(work_centers_new);

CREATE INDEX idx_supervisor_profiles_work_centers_new 
ON supervisor_profiles USING gin(work_centers_new);

CREATE INDEX idx_time_entries_work_center_new 
ON time_entries(work_center_new);