-- First backup existing data
CREATE TEMP TABLE employee_backup AS 
SELECT 
    id,
    fiscal_name,
    email,
    phone,
    country,
    timezone,
    company_id,
    roles,
    is_active,
    document_type,
    document_number,
    NULLIF(delegation::text, '') as delegation_text,
    pin,
    employee_id,
    created_at,
    updated_at,
    array_to_string(work_centers, ',') as work_centers_text,
    job_positions,
    seniority_date
FROM employee_profiles;

CREATE TEMP TABLE supervisor_backup AS 
SELECT 
    id,
    fiscal_name,
    email,
    phone,
    country,
    timezone,
    company_id,
    is_active,
    document_type,
    document_number,
    array_to_string(work_centers, ',') as work_centers_text,
    array_to_string(delegations, ',') as delegations_text,
    supervisor_type,
    pin,
    employee_id,
    created_at,
    updated_at
FROM supervisor_profiles;

-- Drop all dependent functions first
DROP FUNCTION IF EXISTS get_work_center_delegation(work_center_enum);
DROP FUNCTION IF EXISTS get_employees_by_delegation(delegation_enum);
DROP FUNCTION IF EXISTS get_employees_by_work_center(work_center_enum);
DROP FUNCTION IF EXISTS get_employee_count_by_delegation(delegation_enum);
DROP FUNCTION IF EXISTS get_employee_count_by_work_center(work_center_enum);
DROP FUNCTION IF EXISTS map_work_center(text);

-- Drop tables that use the types
DROP TABLE IF EXISTS employee_profiles CASCADE;
DROP TABLE IF EXISTS supervisor_profiles CASCADE;

-- Drop the types
DROP TYPE IF EXISTS work_center_enum CASCADE;
DROP TYPE IF EXISTS delegation_enum CASCADE;

-- Create new types
CREATE TYPE delegation_enum AS ENUM (
    'MADRID',
    'ALAVA',
    'SANTANDER',
    'SEVILLA',
    'VALLADOLID',
    'MURCIA',
    'BURGOS',
    'ALICANTE',
    'CONCEPCION (LA)',
    'CADIZ',
    'PALENCIA',
    'CORDOBA'
);

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
    'CONCEPCION (LA) LINEA CAI / CARMEN HERRERO',
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
    'CONCEPCION (LA) LINEA ESPIGON',
    'CONCEPCION (LA) LINEA MATILDE GALVEZ',
    'CONCEPCION (LA) LINEA GIBRALTAR',
    'CONCEPCION (LA) LINEA EL ROSARIO',
    'CONCEPCION (LA) LINEA PUNTO DE ENCUENTRO',
    'CONCEPCION (LA) LINEA SOROLLA',
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
    'CORDOBA CASA HOGAR POLIFEMO'
);

-- Recreate tables with new types
CREATE TABLE employee_profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    fiscal_name text NOT NULL,
    email text UNIQUE NOT NULL,
    phone text,
    country text NOT NULL DEFAULT 'España',
    timezone text NOT NULL DEFAULT 'Europe/Madrid',
    company_id uuid REFERENCES company_profiles(id),
    roles text[] DEFAULT ARRAY['employee'],
    is_active boolean DEFAULT true,
    document_type text CHECK (document_type IN ('DNI', 'NIE', 'Pasaporte')),
    document_number text,
    delegation delegation_enum,
    pin text NOT NULL CHECK (pin ~ '^\d{6}$'),
    employee_id text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    work_centers work_center_enum[] DEFAULT '{}',
    job_positions job_position_enum[] DEFAULT '{}',
    seniority_date date
);

CREATE TABLE supervisor_profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    fiscal_name text NOT NULL,
    email text UNIQUE NOT NULL,
    phone text,
    country text NOT NULL DEFAULT 'España',
    timezone text NOT NULL DEFAULT 'Europe/Madrid',
    company_id uuid REFERENCES company_profiles(id),
    is_active boolean DEFAULT true,
    document_type text CHECK (document_type IN ('DNI', 'NIE', 'Pasaporte')),
    document_number text,
    work_centers work_center_enum[] DEFAULT '{}',
    delegations delegation_enum[] DEFAULT '{}',
    supervisor_type text CHECK (supervisor_type IN ('center', 'delegation')),
    pin text NOT NULL CHECK (pin ~ '^\d{6}$'),
    employee_id text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Insert data from backup tables with updated values
INSERT INTO employee_profiles 
SELECT 
    eb.id,
    eb.fiscal_name,
    eb.email,
    eb.phone,
    eb.country,
    eb.timezone,
    eb.company_id,
    eb.roles,
    eb.is_active,
    eb.document_type,
    eb.document_number,
    CASE 
        WHEN eb.delegation_text = 'LA' THEN 'CONCEPCION (LA)'::delegation_enum
        WHEN eb.delegation_text IS NOT NULL THEN eb.delegation_text::delegation_enum
        ELSE NULL
    END,
    eb.pin,
    eb.employee_id,
    eb.created_at,
    eb.updated_at,
    ARRAY(
        SELECT DISTINCT 
            CASE 
                WHEN wc = 'LA LINEA CAI / CARMEN HERRERO' THEN 'CONCEPCION (LA) LINEA CAI / CARMEN HERRERO'
                WHEN wc = 'LA LINEA ESPIGON' THEN 'CONCEPCION (LA) LINEA ESPIGON'
                WHEN wc = 'LA LINEA MATILDE GALVEZ' THEN 'CONCEPCION (LA) LINEA MATILDE GALVEZ'
                WHEN wc = 'LA LINEA GIBRALTAR' THEN 'CONCEPCION (LA) LINEA GIBRALTAR'
                WHEN wc = 'LA LINEA EL ROSARIO' THEN 'CONCEPCION (LA) LINEA EL ROSARIO'
                WHEN wc = 'LA LINEA PUNTO DE ENCUENTRO' THEN 'CONCEPCION (LA) LINEA PUNTO DE ENCUENTRO'
                WHEN wc = 'LA LINEA SOROLLA' THEN 'CONCEPCION (LA) LINEA SOROLLA'
                ELSE wc
            END::work_center_enum
        FROM regexp_split_to_table(NULLIF(eb.work_centers_text, ''), ',') wc
        WHERE wc != 'PROFESIONALES'
    ),
    eb.job_positions,
    eb.seniority_date
FROM employee_backup eb;

INSERT INTO supervisor_profiles 
SELECT 
    sb.id,
    sb.fiscal_name,
    sb.email,
    sb.phone,
    sb.country,
    sb.timezone,
    sb.company_id,
    sb.is_active,
    sb.document_type,
    sb.document_number,
    ARRAY(
        SELECT DISTINCT 
            CASE 
                WHEN wc = 'LA LINEA CAI / CARMEN HERRERO' THEN 'CONCEPCION (LA) LINEA CAI / CARMEN HERRERO'
                WHEN wc = 'LA LINEA ESPIGON' THEN 'CONCEPCION (LA) LINEA ESPIGON'
                WHEN wc = 'LA LINEA MATILDE GALVEZ' THEN 'CONCEPCION (LA) LINEA MATILDE GALVEZ'
                WHEN wc = 'LA LINEA GIBRALTAR' THEN 'CONCEPCION (LA) LINEA GIBRALTAR'
                WHEN wc = 'LA LINEA EL ROSARIO' THEN 'CONCEPCION (LA) LINEA EL ROSARIO'
                WHEN wc = 'LA LINEA PUNTO DE ENCUENTRO' THEN 'CONCEPCION (LA) LINEA PUNTO DE ENCUENTRO'
                WHEN wc = 'LA LINEA SOROLLA' THEN 'CONCEPCION (LA) LINEA SOROLLA'
                ELSE wc
            END::work_center_enum
        FROM regexp_split_to_table(NULLIF(sb.work_centers_text, ''), ',') wc
        WHERE wc != 'PROFESIONALES'
    ),
    ARRAY(
        SELECT DISTINCT 
            CASE 
                WHEN d = 'LA' THEN 'CONCEPCION (LA)'::delegation_enum
                ELSE d::delegation_enum
            END
        FROM regexp_split_to_table(NULLIF(sb.delegations_text, ''), ',') d
        WHERE d != 'PROFESIONALES'
    ),
    sb.supervisor_type,
    sb.pin,
    sb.employee_id,
    sb.created_at,
    sb.updated_at
FROM supervisor_backup sb;

-- Create function to get work center delegation
CREATE OR REPLACE FUNCTION get_work_center_delegation(p_work_center work_center_enum)
RETURNS delegation_enum AS $$
DECLARE
    v_prefix TEXT;
BEGIN
    v_prefix := split_part(p_work_center::text, ' ', 1);
    RETURN CASE v_prefix
        WHEN 'MADRID' THEN 'MADRID'
        WHEN 'ALAVA' THEN 'ALAVA'
        WHEN 'SANTANDER' THEN 'SANTANDER'
        WHEN 'SEVILLA' THEN 'SEVILLA'
        WHEN 'VALLADOLID' THEN 'VALLADOLID'
        WHEN 'MURCIA' THEN 'MURCIA'
        WHEN 'BURGOS' THEN 'BURGOS'
        WHEN 'CONCEPCION' THEN 'CONCEPCION (LA)'
        WHEN 'CADIZ' THEN 'CADIZ'
        WHEN 'ALICANTE' THEN 'ALICANTE'
        WHEN 'PALENCIA' THEN 'PALENCIA'
        WHEN 'CORDOBA' THEN 'CORDOBA'
        ELSE NULL
    END::delegation_enum;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create indexes
CREATE INDEX idx_employee_profiles_delegation ON employee_profiles(delegation);
CREATE INDEX idx_employee_profiles_work_centers ON employee_profiles USING gin(work_centers);
CREATE INDEX idx_supervisor_profiles_work_centers ON supervisor_profiles USING gin(work_centers);
CREATE INDEX idx_supervisor_profiles_delegations ON supervisor_profiles USING gin(delegations);

-- Drop temporary tables
DROP TABLE employee_backup;
DROP TABLE supervisor_backup;