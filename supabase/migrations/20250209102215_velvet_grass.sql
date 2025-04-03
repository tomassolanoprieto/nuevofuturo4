-- Drop existing type if exists
DROP TYPE IF EXISTS job_position_enum CASCADE;

-- Create new job_position_enum type with updated values
CREATE TYPE job_position_enum AS ENUM (
  'EDUCADOR/A SOCIAL',
  'AUX. TÉCNICO/A EDUCATIVO/A',
  'GERENTE',
  'DIRECTOR EMANCIPACION',
  'PSICOLOGO/A',
  'ADMINISTRATIVO/A',
  'EDUCADOR/A RESPONSABLE',
  'TEC. INT. SOCIAL',
  'APOYO DOMESTICO',
  'OFICIAL/A DE MANTENIMIENTO',
  'PEDAGOGO/A',
  'CONTABLE',
  'TRABAJADOR/A SOCIAL',
  'COCINERO/A',
  'COORDINADOR/A',
  'DIRECTOR/A HOGAR',
  'RESPONSABLE HOGAR',
  'AUX. SERV. GRALES',
  'ADVO/A. CONTABLE',
  'LIMPIEZA',
  'AUX. ADMVO/A',
  'DIRECTOR/A',
  'JEFE/A ADMINISTRACIÓN',
  'DIRECTORA POSTACOGIMIENTO',
  'COORD. TERRITORIAL CASTILLA Y LEON',
  'DIRECTOR COMUNICACION',
  'AUX. GEST. ADVA',
  'RESPONSABLE RRHH',
  'COORD. TERRITORIAL ANDALUCIA'
);

-- Add job_positions column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'employee_profiles' 
        AND column_name = 'job_positions'
    ) THEN
        ALTER TABLE employee_profiles
        ADD COLUMN job_positions job_position_enum[] DEFAULT '{}';
    END IF;
END $$;

-- Create index for job_positions
CREATE INDEX IF NOT EXISTS idx_employee_profiles_job_positions 
ON employee_profiles USING gin(job_positions);