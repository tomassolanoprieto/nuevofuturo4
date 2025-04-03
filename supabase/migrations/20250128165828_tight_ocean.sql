-- Create job_position enum
CREATE TYPE job_position_enum AS ENUM (
  'Psicólogo/a',
  'Auxiliar técnico educativo',
  'Responsable Hogar',
  'Educador/a social',
  'Director/a',
  'Auxiliar 0,70%',
  'Aux. Administración',
  'Auxiliar Servicios Generales',
  'Trabajador/a Social',
  'Director/a Programas',
  'Director/a RRHH',
  'Aux. Mantenimiento',
  'Director/a Recursos Económicos'
);

-- Add new columns to employee_profiles
ALTER TABLE employee_profiles
ADD COLUMN IF NOT EXISTS employee_id TEXT,
ADD COLUMN IF NOT EXISTS seniority_date DATE,
ADD COLUMN IF NOT EXISTS job_positions job_position_enum[] DEFAULT '{}';