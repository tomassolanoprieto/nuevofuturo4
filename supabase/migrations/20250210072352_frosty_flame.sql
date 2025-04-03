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
    'LA',
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
        WHEN 'LA LINEA' THEN 'LA'::delegation_enum
        WHEN 'CADIZ' THEN 'CADIZ'::delegation_enum
        WHEN 'CÁDIZ' THEN 'CADIZ'::delegation_enum
        WHEN 'PALENCIA' THEN 'PALENCIA'::delegation_enum
        WHEN 'CORDOBA' THEN 'CORDOBA'::delegation_enum
        WHEN 'CÓRDOBA' THEN 'CORDOBA'::delegation_enum
        ELSE delegation
    END
    WHERE delegation IS NOT NULL;
END $$;

-- Create function to get delegation for a work center
CREATE OR REPLACE FUNCTION get_work_center_delegation(p_work_center work_center_enum)
RETURNS delegation_enum AS $$
DECLARE
  v_prefix TEXT;
BEGIN
  -- Extract prefix (first word) from work center
  v_prefix := split_part(p_work_center::text, ' ', 1);
  
  -- Map prefix to delegation
  RETURN CASE v_prefix
    WHEN 'MADRID' THEN 'MADRID'
    WHEN 'ALAVA' THEN 'ALAVA'
    WHEN 'SANTANDER' THEN 'SANTANDER'
    WHEN 'SEVILLA' THEN 'SEVILLA'
    WHEN 'VALLADOLID' THEN 'VALLADOLID'
    WHEN 'MURCIA' THEN 'MURCIA'
    WHEN 'BURGOS' THEN 'BURGOS'
    WHEN 'LA' THEN 'LA'
    WHEN 'CADIZ' THEN 'CADIZ'
    WHEN 'ALICANTE' THEN 'ALICANTE'
    WHEN 'PALENCIA' THEN 'PALENCIA'
    WHEN 'CORDOBA' THEN 'CORDOBA'
    WHEN 'PROFESIONALES' THEN 'PROFESIONALES'
    ELSE NULL
  END::delegation_enum;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create trigger function to automatically set delegation based on work centers
CREATE OR REPLACE FUNCTION set_delegation_from_work_centers()
RETURNS TRIGGER AS $$
BEGIN
  -- Get the delegation from the first work center
  IF array_length(NEW.work_centers, 1) > 0 THEN
    NEW.delegation := get_work_center_delegation(NEW.work_centers[1]);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically set delegation
DROP TRIGGER IF EXISTS set_delegation_trigger ON employee_profiles;
CREATE TRIGGER set_delegation_trigger
  BEFORE INSERT OR UPDATE OF work_centers ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION set_delegation_from_work_centers();

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation 
ON employee_profiles(delegation);

-- Update existing records to ensure delegations match work centers
UPDATE employee_profiles ep
SET delegation = (
  SELECT get_work_center_delegation(work_centers[1])
  FROM employee_profiles
  WHERE id = ep.id
  AND array_length(work_centers, 1) > 0
)
WHERE array_length(work_centers, 1) > 0;