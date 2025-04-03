-- Función para normalizar los work centers
CREATE OR REPLACE FUNCTION normalize_work_centers(centers work_center_enum[])
RETURNS work_center_enum[] AS $$
DECLARE
  normalized work_center_enum[];
  center text;
BEGIN
  -- Inicializar array vacío
  normalized := ARRAY[]::work_center_enum[];
  
  -- Procesar cada centro
  IF centers IS NOT NULL THEN
    FOREACH center IN ARRAY centers
    LOOP
      -- Limpiar y normalizar el valor
      center := trim(both '"' from trim(both '{}' from center::text));
      -- Añadir al array si es válido
      BEGIN
        normalized := array_append(normalized, center::work_center_enum);
      EXCEPTION
        WHEN invalid_text_representation THEN
          -- Ignorar valores inválidos
          CONTINUE;
      END;
    END LOOP;
  END IF;
  
  RETURN normalized;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Función para normalizar las delegaciones
CREATE OR REPLACE FUNCTION normalize_delegations(dels delegation_enum[])
RETURNS delegation_enum[] AS $$
DECLARE
  normalized delegation_enum[];
  del text;
BEGIN
  -- Inicializar array vacío
  normalized := ARRAY[]::delegation_enum[];
  
  -- Procesar cada delegación
  IF dels IS NOT NULL THEN
    FOREACH del IN ARRAY dels
    LOOP
      -- Limpiar y normalizar el valor
      del := trim(both '"' from trim(both '{}' from del::text));
      -- Añadir al array si es válido
      BEGIN
        normalized := array_append(normalized, del::delegation_enum);
      EXCEPTION
        WHEN invalid_text_representation THEN
          -- Ignorar valores inválidos
          CONTINUE;
      END;
    END LOOP;
  END IF;
  
  RETURN normalized;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Actualizar los datos existentes
UPDATE employee_profiles
SET 
  work_centers = normalize_work_centers(work_centers),
  delegation = CASE 
    WHEN delegation::text = 'LA LINEA' THEN 'LA'::delegation_enum
    ELSE delegation
  END;

UPDATE supervisor_profiles
SET 
  work_centers = normalize_work_centers(work_centers),
  delegations = normalize_delegations(delegations);

-- Crear índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers_gin
ON employee_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_work_centers_gin
ON supervisor_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_delegations_gin
ON supervisor_profiles USING gin(delegations);