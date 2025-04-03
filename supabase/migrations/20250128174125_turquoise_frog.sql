/*
  # Add job positions to employee profiles

  1. Changes
    - Add job_positions array column to employee_profiles table
    - Create job_position_enum type if it doesn't exist
    - Create index for better performance

  2. Notes
    - Uses array type to support multiple positions per employee
    - Adds GIN index for efficient array queries
*/

-- Create job_position enum if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'job_position_enum') THEN
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
    END IF;
END $$;

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

-- Create index for job_positions for better performance
CREATE INDEX IF NOT EXISTS employee_profiles_job_positions_idx 
ON employee_profiles USING GIN(job_positions);