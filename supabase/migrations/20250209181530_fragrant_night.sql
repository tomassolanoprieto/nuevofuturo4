-- Drop existing types if they exist
DROP TYPE IF EXISTS delegation_enum CASCADE;
DROP TYPE IF EXISTS work_center_enum CASCADE;
DROP TYPE IF EXISTS job_position_enum CASCADE;

-- Create delegation_enum type
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

-- Create work_center_enum type
CREATE TYPE work_center_enum AS ENUM (
    'MADRID HOGARES DE EMANCIPACION V. DEL PARDILLO',
    'ALAVA HAZIBIDE',
    'SANTANDER OFICINA',
    'MADRID CUEVAS DE ALMANZORA',
    'SEVILLA ROSALEDA',
    'SEVILLA CASTILLEJA',
    'SANTANDER ALISAL',
    'VALLADOLID MIRLO',
    'MURCIA EL VERDOLAY',
    'BURGOS CERVANTES',
    'MADRID OFICINA',
    'LA LINEA CAI / CARMEN HERRERO',
    'CADIZ CARLOS HAYA',
    'MADRID ALCOBENDAS',
    'MADRID MIGUEL HERNANDEZ',
    'MADRID HUMANITARIAS',
    'MADRID VALDEBERNARDO',
    'MADRID JOSE DE PASAMONTE',
    'MADRID IBIZA',
    'MADRID PASEO EXTREMADURA',
    'MADRID DIRECTORES DE CENTRO',
    'MADRID GABRIEL USERA',
    'MADRID ARROYO DE LAS PILILLAS',
    'MADRID CENTRO DE DIA CARMEN HERRERO',
    'MADRID HOGARES DE EMANCIPACION SANTA CLARA',
    'MADRID HOGARES DE EMANCIPACION BOCANGEL',
    'MADRID AVDA DE AMERICA',
    'MADRID VIRGEN DEL PUIG',
    'MADRID ALMACEN',
    'MADRID HOGARES DE EMANCIPACION ROQUETAS',
    'ALAVA PAULA MONTAL',
    'ALAVA SENDOA',
    'ALAVA EKILORE',
    'ALAVA GESTIÓN AUKERA',
    'ALAVA GESTIÓN HOGARES',
    'ALAVA XABIER',
    'ALAVA ATENCION DIRECTA',
    'ALAVA PROGRAMA DE SEGUIMIENTO',
    'SANTANDER MARIA NEGRETE (CENTRO DE DÍA)',
    'SANTANDER ASTILLERO',
    'BURGOS CORTES',
    'BURGOS ARANDA',
    'BURGOS OFICINA',
    'LA LINEA ESPIGON',
    'LA LINEA MATILDE GALVEZ',
    'LA LINEA GIBRALTAR',
    'LA LINEA EL ROSARIO',
    'LA LINEA PUNTO DE ENCUENTRO',
    'LA LINEA SOROLLA',
    'CADIZ TRILLE',
    'CADIZ GRANJA',
    'CADIZ OFICINA',
    'CADIZ ESQUIVEL',
    'SEVILLA PARAISO',
    'SEVILLA VARIOS',
    'SEVILLA OFICINA',
    'SEVILLA JAP NF+18',
    'MURCIA HOGAR DE SAN ISIDRO',
    'MURCIA HOGAR DE SAN BASILIO',
    'MURCIA OFICINA',
    'ALICANTE EL PINO',
    'ALICANTE EMANCIPACION LOS NARANJOS',
    'ALICANTE EMANCIPACION BENACANTIL',
    'ALICANTE EL POSTIGUET',
    'PALENCIA',
    'CORDOBA CASA HOGAR POLIFEMO',
    'PROFESIONALES'
);

-- Create job_position_enum type
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

-- Add columns if they don't exist
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

    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'employee_profiles' 
        AND column_name = 'work_centers'
    ) THEN
        ALTER TABLE employee_profiles
        ADD COLUMN work_centers work_center_enum[] DEFAULT '{}';
    END IF;

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
    WHEN 'LA' THEN 'LA LINEA'
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

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation 
ON employee_profiles(delegation);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers 
ON employee_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_job_positions 
ON employee_profiles USING gin(job_positions);

-- Update existing records to ensure delegations match work centers
UPDATE employee_profiles ep
SET delegation = (
  SELECT get_work_center_delegation(work_centers[1])
  FROM employee_profiles
  WHERE id = ep.id
  AND array_length(work_centers, 1) > 0
)
WHERE array_length(work_centers, 1) > 0;