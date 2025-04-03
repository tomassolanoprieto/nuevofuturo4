-- Create function to get filtered requests for delegation
CREATE OR REPLACE FUNCTION get_delegation_filtered_requests(
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
BEGIN
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

-- Create function to get calendar events for delegation
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
BEGIN
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
  WHERE (h.work_center IS NULL OR h.work_center = p_work_center)
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

-- Create function to get delegation work centers
CREATE OR REPLACE FUNCTION get_delegation_work_centers(
  p_delegation delegation_enum
)
RETURNS SETOF work_center_enum AS $$
  SELECT DISTINCT unnest(work_centers)
  FROM employee_profiles
  WHERE delegation = p_delegation
  AND is_active = true
  ORDER BY 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- Create function to get delegation supervisors
CREATE OR REPLACE FUNCTION get_delegation_supervisors(
  p_delegation delegation_enum
)
RETURNS TABLE (
  id UUID,
  fiscal_name TEXT,
  email TEXT,
  supervisor_type TEXT,
  work_centers work_center_enum[],
  delegations delegation_enum[],
  is_active BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sp.id,
    sp.fiscal_name,
    sp.email,
    sp.supervisor_type,
    sp.work_centers,
    sp.delegations,
    sp.is_active
  FROM supervisor_profiles sp
  WHERE p_delegation = ANY(sp.delegations)
  AND sp.is_active = true
  ORDER BY sp.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation 
ON employee_profiles(delegation);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_delegations 
ON supervisor_profiles USING gin(delegations);

CREATE INDEX IF NOT EXISTS idx_time_requests_created_at 
ON time_requests(created_at);

CREATE INDEX IF NOT EXISTS idx_planner_requests_created_at 
ON planner_requests(created_at);

CREATE INDEX IF NOT EXISTS idx_holidays_date 
ON holidays(date);

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_delegation_filtered_requests TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION get_delegation_calendar_events TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION get_delegation_work_centers TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION get_delegation_supervisors TO anon, PUBLIC;