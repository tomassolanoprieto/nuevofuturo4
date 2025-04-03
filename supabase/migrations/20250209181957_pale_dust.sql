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

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation 
ON employee_profiles(delegation);