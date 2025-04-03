-- Create table to map work centers to delegations
CREATE TABLE IF NOT EXISTS work_center_delegation_mapping (
  work_center work_center_enum PRIMARY KEY,
  delegation delegation_enum NOT NULL
);

-- Insert mappings for all work centers
INSERT INTO work_center_delegation_mapping (work_center, delegation) VALUES
  -- Madrid
  ('MADRID HOGARES DE EMANCIPACION V. DEL PARDILLO', 'Madrid'),
  ('MADRID CUEVAS DE ALMANZORA', 'Madrid'),
  ('MADRID OFICINA', 'Madrid'),
  ('MADRID ALCOBENDAS', 'Madrid'),
  ('MADRID JOSE DE PASAMONTE', 'Madrid'),
  ('MADRID VALDEBERNARDO', 'Madrid'),
  ('MADRID MIGUEL HERNANDEZ', 'Madrid'),
  ('MADRID GABRIEL USERA', 'Madrid'),
  ('MADRID IBIZA', 'Madrid'),
  ('MADRID DIRECTORES DE CENTRO', 'Madrid'),
  ('MADRID HUMANITARIAS', 'Madrid'),
  ('MADRID VIRGEN DEL PUIG', 'Madrid'),
  ('MADRID ALMACEN', 'Madrid'),
  ('MADRID PASEO EXTREMADURA', 'Madrid'),
  ('MADRID HOGARES DE EMANCIPACION SANTA CLARA', 'Madrid'),
  ('MADRID ARROYO DE LAS PILILLAS', 'Madrid'),
  ('MADRID AVDA DE AMERICA', 'Madrid'),
  ('MADRID CENTRO DE DIA CARMEN HERRERO', 'Madrid'),
  ('MADRID HOGARES DE EMANCIPACION BOCANGEL', 'Madrid'),
  ('MADRID HOGARES DE EMANCIPACION ROQUETAS', 'Madrid'),

  -- Álava
  ('ALAVA HAZIBIDE', 'Álava'),
  ('ALAVA PAULA MONTAL', 'Álava'),
  ('ALAVA SENDOA', 'Álava'),
  ('ALAVA EKILORE', 'Álava'),
  ('ALAVA GESTIÓN AUKERA', 'Álava'),
  ('ALAVA GESTIÓN HOGARES', 'Álava'),
  ('ALAVA XABIER', 'Álava'),
  ('ALAVA ATENCION DIRECTA', 'Álava'),
  ('ALAVA PROGRAMA DE SEGUIMIENTO', 'Álava'),

  -- Santander
  ('SANTANDER OFICINA', 'Santander'),
  ('SANTANDER ALISAL', 'Santander'),
  ('SANTANDER MARIA NEGRETE (CENTRO DE DÍA)', 'Santander'),
  ('SANTANDER ASTILLERO', 'Santander'),

  -- Sevilla
  ('SEVILLA ROSALEDA', 'Sevilla'),
  ('SEVILLA CASTILLEJA', 'Sevilla'),
  ('SEVILLA PARAISO', 'Sevilla'),
  ('SEVILLA VARIOS', 'Sevilla'),
  ('SEVILLA OFICINA', 'Sevilla'),
  ('SEVILLA JAP NF+18', 'Sevilla'),

  -- Murcia
  ('MURCIA EL VERDOLAY', 'Murcia'),
  ('MURCIA HOGAR DE SAN ISIDRO', 'Murcia'),
  ('MURCIA HOGAR DE SAN BASILIO', 'Murcia'),
  ('MURCIA OFICINA', 'Murcia'),

  -- Burgos
  ('BURGOS CERVANTES', 'Burgos'),
  ('BURGOS CORTES', 'Burgos'),
  ('BURGOS ARANDA', 'Burgos'),
  ('BURGOS OFICINA', 'Burgos'),

  -- Campo Gibraltar
  ('LA LINEA CAI / CARMEN HERRERO', 'Campo Gibraltar'),
  ('LA LINEA ESPIGON', 'Campo Gibraltar'),
  ('LA LINEA MATILDE GALVEZ', 'Campo Gibraltar'),
  ('LA LINEA GIBRALTAR', 'Campo Gibraltar'),
  ('LA LINEA EL ROSARIO', 'Campo Gibraltar'),
  ('LA LINEA PUNTO DE ENCUENTRO', 'Campo Gibraltar'),
  ('LA LINEA SOROLLA', 'Campo Gibraltar'),

  -- Cádiz
  ('CADIZ CARLOS HAYA', 'Cádiz'),
  ('CADIZ TRILLE', 'Cádiz'),
  ('CADIZ GRANJA', 'Cádiz'),
  ('CADIZ OFICINA', 'Cádiz'),
  ('CADIZ ESQUIVEL', 'Cádiz'),

  -- Alicante
  ('ALICANTE EL PINO', 'Alicante'),
  ('ALICANTE EMANCIPACION LOS NARANJOS', 'Alicante'),
  ('ALICANTE EMANCIPACION BENACANTIL', 'Alicante'),
  ('ALICANTE EL POSTIGUET', 'Alicante'),

  -- Palencia
  ('PALENCIA', 'Palencia'),

  -- Córdoba
  ('CORDOBA CASA HOGAR POLIFEMO', 'Córdoba'),

  -- Otros
  ('PROFESIONALES', 'Madrid'),
  ('VALLADOLID MIRLO', 'Valladolid');

-- Create function to get delegation for a work center
CREATE OR REPLACE FUNCTION get_work_center_delegation(p_work_center work_center_enum)
RETURNS delegation_enum AS $$
  SELECT delegation 
  FROM work_center_delegation_mapping 
  WHERE work_center = p_work_center;
$$ LANGUAGE sql STABLE;

-- Create function to get work centers for a delegation
CREATE OR REPLACE FUNCTION get_delegation_work_centers(p_delegation delegation_enum)
RETURNS SETOF work_center_enum AS $$
  SELECT work_center 
  FROM work_center_delegation_mapping 
  WHERE delegation = p_delegation;
$$ LANGUAGE sql STABLE;

-- Create function to validate work center belongs to delegation
CREATE OR REPLACE FUNCTION validate_work_center_delegation(p_work_center work_center_enum, p_delegation delegation_enum)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM work_center_delegation_mapping 
    WHERE work_center = p_work_center 
    AND delegation = p_delegation
  );
$$ LANGUAGE sql STABLE;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_work_center_delegation_mapping_delegation 
ON work_center_delegation_mapping(delegation);