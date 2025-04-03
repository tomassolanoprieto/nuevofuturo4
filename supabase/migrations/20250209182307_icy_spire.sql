-- Drop existing type if exists
DROP TYPE IF EXISTS delegation_enum CASCADE;

-- Create new delegation_enum type with updated values
CREATE TYPE delegation_enum AS ENUM (
    'MADRID',
    'ALAVA',
    'SANTANDER',
    'SEVILLA',
    'VALLADOLID',
    'MURCIA',
    'BURGOS',
    'PROFESIONALES',
    'ALICANTE',
    'LA LINEA',
    'CADIZ',
    'PALENCIA',
    'CORDOBA'
);

-- Add delegation column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'employee_profiles' 
        AND column_name = 'delegation'
    ) THEN
        ALTER TABLE employee_profiles
        ADD COLUMN delegation delegation_enum;
    END IF;
END $$;

-- Update existing employee delegations to match new format
DO $$
BEGIN
    -- Update existing records with case-insensitive matching
    UPDATE employee_profiles
    SET delegation = CASE UPPER(delegation::text)
        WHEN 'MADRID' THEN 'MADRID'::delegation_enum
        WHEN 'ALAVA' THEN 'ALAVA'::delegation_enum
        WHEN 'ÁLAVA' THEN 'ALAVA'::delegation_enum
        WHEN 'SANTANDER' THEN 'SANTANDER'::delegation_enum
        WHEN 'SEVILLA' THEN 'SEVILLA'::delegation_enum
        WHEN 'VALLADOLID' THEN 'VALLADOLID'::delegation_enum
        WHEN 'MURCIA' THEN 'MURCIA'::delegation_enum
        WHEN 'BURGOS' THEN 'BURGOS'::delegation_enum
        WHEN 'PROFESIONALES' THEN 'PROFESIONALES'::delegation_enum
        WHEN 'ALICANTE' THEN 'ALICANTE'::delegation_enum
        WHEN 'LA LINEA' THEN 'LA LINEA'::delegation_enum
        WHEN 'CADIZ' THEN 'CADIZ'::delegation_enum
        WHEN 'CÁDIZ' THEN 'CADIZ'::delegation_enum
        WHEN 'PALENCIA' THEN 'PALENCIA'::delegation_enum
        WHEN 'CORDOBA' THEN 'CORDOBA'::delegation_enum
        WHEN 'CÓRDOBA' THEN 'CORDOBA'::delegation_enum
        ELSE delegation
    END
    WHERE delegation IS NOT NULL;
END $$;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation 
ON employee_profiles(delegation);