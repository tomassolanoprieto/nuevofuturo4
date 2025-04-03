-- Create function to get work centers for a delegation
CREATE OR REPLACE FUNCTION get_work_centers_by_delegation(p_delegation delegation_enum)
RETURNS work_center_enum[] AS $$
BEGIN
  RETURN CASE p_delegation
    WHEN 'MADRID' THEN ARRAY[
      'MADRID HOGARES DE EMANCIPACION V. DEL PARDILLO',
      'MADRID CUEVAS DE ALMANZORA',
      'MADRID OFICINA',
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
      'MADRID HOGARES DE EMANCIPACION ROQUETAS'
    ]::work_center_enum[]
    WHEN 'ALAVA' THEN ARRAY[
      'ALAVA HAZIBIDE',
      'ALAVA PAULA MONTAL',
      'ALAVA SENDOA',
      'ALAVA EKILORE',
      'ALAVA GESTIÓN AUKERA',
      'ALAVA GESTIÓN HOGARES',
      'ALAVA XABIER',
      'ALAVA ATENCION DIRECTA',
      'ALAVA PROGRAMA DE SEGUIMIENTO'
    ]::work_center_enum[]
    WHEN 'SANTANDER' THEN ARRAY[
      'SANTANDER OFICINA',
      'SANTANDER ALISAL',
      'SANTANDER MARIA NEGRETE (CENTRO DE DÍA)',
      'SANTANDER ASTILLERO'
    ]::work_center_enum[]
    WHEN 'SEVILLA' THEN ARRAY[
      'SEVILLA ROSALEDA',
      'SEVILLA CASTILLEJA',
      'SEVILLA PARAISO',
      'SEVILLA VARIOS',
      'SEVILLA OFICINA',
      'SEVILLA JAP NF+18'
    ]::work_center_enum[]
    WHEN 'VALLADOLID' THEN ARRAY[
      'VALLADOLID MIRLO'
    ]::work_center_enum[]
    WHEN 'MURCIA' THEN ARRAY[
      'MURCIA EL VERDOLAY',
      'MURCIA HOGAR DE SAN ISIDRO',
      'MURCIA HOGAR DE SAN BASILIO',
      'MURCIA OFICINA'
    ]::work_center_enum[]
    WHEN 'BURGOS' THEN ARRAY[
      'BURGOS CERVANTES',
      'BURGOS CORTES',
      'BURGOS ARANDA',
      'BURGOS OFICINA'
    ]::work_center_enum[]
    WHEN 'ALICANTE' THEN ARRAY[
      'ALICANTE EL PINO',
      'ALICANTE EMANCIPACION LOS NARANJOS',
      'ALICANTE EMANCIPACION BENACANTIL',
      'ALICANTE EL POSTIGUET'
    ]::work_center_enum[]
    WHEN 'CONCEPCION_LA' THEN ARRAY[
      'CONCEPCION_LA LINEA CAI / CARMEN HERRERO',
      'CONCEPCION_LA LINEA ESPIGON',
      'CONCEPCION_LA LINEA MATILDE GALVEZ',
      'CONCEPCION_LA LINEA GIBRALTAR',
      'CONCEPCION_LA LINEA EL ROSARIO',
      'CONCEPCION_LA LINEA PUNTO DE ENCUENTRO',
      'CONCEPCION_LA LINEA SOROLLA'
    ]::work_center_enum[]
    WHEN 'CADIZ' THEN ARRAY[
      'CADIZ CARLOS HAYA',
      'CADIZ TRILLE',
      'CADIZ GRANJA',
      'CADIZ OFICINA',
      'CADIZ ESQUIVEL'
    ]::work_center_enum[]
    WHEN 'PALENCIA' THEN ARRAY[
      'PALENCIA'
    ]::work_center_enum[]
    WHEN 'CORDOBA' THEN ARRAY[
      'CORDOBA CASA HOGAR POLIFEMO'
    ]::work_center_enum[]
    ELSE NULL
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create function to get filtered requests by delegation
CREATE OR REPLACE FUNCTION get_filtered_requests_by_delegation(
  p_delegation delegation_enum,
  p_work_center work_center_enum DEFAULT NULL,
  p_start_date TIMESTAMPTZ DEFAULT NULL,
  p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
  request_id UUID,
  request_type TEXT,
  request_status TEXT,
  created_at TIMESTAMPTZ,
  employee_id UUID,
  employee_name TEXT,
  employee_email TEXT,
  work_centers work_center_enum[],
  delegation delegation_enum,
  details JSONB
) AS $$
DECLARE
  v_work_centers work_center_enum[];
BEGIN
  -- Get work centers for the delegation
  v_work_centers := get_work_centers_by_delegation(p_delegation);
  
  IF v_work_centers IS NULL THEN
    RAISE EXCEPTION 'No se encontraron centros de trabajo para la delegación %', p_delegation;
  END IF;

  -- Return combined results from time_requests and planner_requests
  RETURN QUERY
  -- Time requests
  SELECT
    tr.id as request_id,
    'time'::TEXT as request_type,
    tr.status as request_status,
    tr.created_at,
    tr.employee_id,
    ep.fiscal_name as employee_name,
    ep.email as employee_email,
    ep.work_centers,
    ep.delegation,
    jsonb_build_object(
      'datetime', tr.datetime,
      'entry_type', tr.entry_type,
      'comment', tr.comment
    ) as details
  FROM time_requests tr
  JOIN employee_profiles ep ON ep.id = tr.employee_id
  WHERE ep.delegation = p_delegation
  AND ep.is_active = true
  AND (
    p_work_center IS NULL OR 
    p_work_center = ANY(ep.work_centers)
  )
  AND (
    p_start_date IS NULL OR 
    tr.created_at >= p_start_date
  )
  AND (
    p_end_date IS NULL OR 
    tr.created_at <= p_end_date
  )

  UNION ALL

  -- Planner requests
  SELECT
    pr.id as request_id,
    'planner'::TEXT as request_type,
    pr.status as request_status,
    pr.created_at,
    pr.employee_id,
    ep.fiscal_name as employee_name,
    ep.email as employee_email,
    ep.work_centers,
    ep.delegation,
    jsonb_build_object(
      'planner_type', pr.planner_type,
      'start_date', pr.start_date,
      'end_date', pr.end_date,
      'comment', pr.comment
    ) as details
  FROM planner_requests pr
  JOIN employee_profiles ep ON ep.id = pr.employee_id
  WHERE ep.delegation = p_delegation
  AND ep.is_active = true
  AND (
    p_work_center IS NULL OR 
    p_work_center = ANY(ep.work_centers)
  )
  AND (
    p_start_date IS NULL OR 
    pr.created_at >= p_start_date
  )
  AND (
    p_end_date IS NULL OR 
    pr.created_at <= p_end_date
  )
  ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get calendar events by delegation
CREATE OR REPLACE FUNCTION get_delegation_calendar_events(
  p_delegation delegation_enum,
  p_work_center work_center_enum DEFAULT NULL,
  p_start_date TIMESTAMPTZ DEFAULT NULL,
  p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
  event_id UUID,
  title TEXT,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  event_type TEXT,
  employee_name TEXT,
  work_center work_center_enum,
  details JSONB
) AS $$
DECLARE
  v_work_centers work_center_enum[];
BEGIN
  -- Get work centers for the delegation
  v_work_centers := get_work_centers_by_delegation(p_delegation);
  
  IF v_work_centers IS NULL THEN
    RAISE EXCEPTION 'No se encontraron centros de trabajo para la delegación %', p_delegation;
  END IF;

  RETURN QUERY
  -- Get planner events
  SELECT
    pr.id as event_id,
    ep.fiscal_name || ' - ' || pr.planner_type as title,
    pr.start_date as start_date,
    pr.end_date as end_date,
    'planner'::TEXT as event_type,
    ep.fiscal_name as employee_name,
    ANY_VALUE(ep.work_centers) as work_center,
    jsonb_build_object(
      'planner_type', pr.planner_type,
      'comment', pr.comment
    ) as details
  FROM planner_requests pr
  JOIN employee_profiles ep ON ep.id = pr.employee_id
  WHERE ep.delegation = p_delegation
  AND ep.is_active = true
  AND pr.status = 'approved'
  AND (
    p_work_center IS NULL OR 
    p_work_center = ANY(ep.work_centers)
  )
  AND (
    p_start_date IS NULL OR 
    pr.end_date >= p_start_date
  )
  AND (
    p_end_date IS NULL OR 
    pr.start_date <= p_end_date
  )

  UNION ALL

  -- Get holiday events
  SELECT
    h.id as event_id,
    h.name as title,
    h.date as start_date,
    h.date as end_date,
    'holiday'::TEXT as event_type,
    NULL as employee_name,
    h.work_center,
    jsonb_build_object(
      'type', h.type
    ) as details
  FROM holidays h
  WHERE (h.work_center IS NULL OR h.work_center = ANY(v_work_centers))
  AND (
    p_start_date IS NULL OR 
    h.date >= p_start_date
  )
  AND (
    p_end_date IS NULL OR 
    h.date <= p_end_date
  )
  ORDER BY start_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get work centers for a delegation
CREATE OR REPLACE FUNCTION get_delegation_work_centers(
  p_delegation delegation_enum
)
RETURNS SETOF work_center_enum AS $$
  SELECT unnest(get_work_centers_by_delegation(p_delegation))
  ORDER BY 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation 
ON employee_profiles(delegation);

CREATE INDEX IF NOT EXISTS idx_time_requests_created_at 
ON time_requests(created_at);

CREATE INDEX IF NOT EXISTS idx_planner_requests_created_at 
ON planner_requests(created_at);

CREATE INDEX IF NOT EXISTS idx_holidays_date 
ON holidays(date);

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_work_centers_by_delegation TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_filtered_requests_by_delegation TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_delegation_calendar_events TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_delegation_work_centers TO PUBLIC;