-- Drop existing type if exists
DROP TYPE IF EXISTS work_center_enum CASCADE;

-- Create new work_center_enum type with updated values
CREATE TYPE work_center_enum AS ENUM (
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

-- Add work_centers column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'employee_profiles' 
        AND column_name = 'work_centers'
    ) THEN
        ALTER TABLE employee_profiles
        ADD COLUMN work_centers work_center_enum[] DEFAULT '{}';
    END IF;
END $$;

-- Create index for work_centers
CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers 
ON employee_profiles USING gin(work_centers);