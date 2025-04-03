-- Create function to get filtered requests
CREATE OR REPLACE FUNCTION get_filtered_requests(
  p_company_id UUID,
  p_work_center work_center_enum DEFAULT NULL,
  p_delegation delegation_enum DEFAULT NULL,
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
  WHERE ep.company_id = p_company_id
  AND ep.is_active = true
  AND (
    p_work_center IS NULL OR 
    p_work_center = ANY(ep.work_centers)
  )
  AND (
    p_delegation IS NULL OR 
    ep.delegation = p_delegation
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
  WHERE ep.company_id = p_company_id
  AND ep.is_active = true
  AND (
    p_work_center IS NULL OR 
    p_work_center = ANY(ep.work_centers)
  )
  AND (
    p_delegation IS NULL OR 
    ep.delegation = p_delegation
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

-- Create function to get filtered requests for supervisor
CREATE OR REPLACE FUNCTION get_supervisor_filtered_requests(
  p_supervisor_id UUID,
  p_work_center work_center_enum DEFAULT NULL,
  p_delegation delegation_enum DEFAULT NULL,
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
  v_supervisor_type TEXT;
  v_supervisor_work_centers work_center_enum[];
  v_supervisor_delegations delegation_enum[];
  v_company_id UUID;
BEGIN
  -- Get supervisor info
  SELECT 
    supervisor_type,
    work_centers,
    delegations,
    company_id
  INTO 
    v_supervisor_type,
    v_supervisor_work_centers,
    v_supervisor_delegations,
    v_company_id
  FROM supervisor_profiles
  WHERE id = p_supervisor_id
  AND is_active = true;

  IF v_supervisor_type IS NULL THEN
    RETURN;
  END IF;

  -- Return filtered requests based on supervisor type
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
  WHERE ep.company_id = v_company_id
  AND ep.is_active = true
  AND (
    (v_supervisor_type = 'center' AND (
      p_work_center IS NULL OR 
      p_work_center = ANY(ep.work_centers)
    ) AND ep.work_centers && v_supervisor_work_centers)
    OR
    (v_supervisor_type = 'delegation' AND (
      p_delegation IS NULL OR 
      ep.delegation = p_delegation
    ) AND ep.delegation = ANY(v_supervisor_delegations))
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
  WHERE ep.company_id = v_company_id
  AND ep.is_active = true
  AND (
    (v_supervisor_type = 'center' AND (
      p_work_center IS NULL OR 
      p_work_center = ANY(ep.work_centers)
    ) AND ep.work_centers && v_supervisor_work_centers)
    OR
    (v_supervisor_type = 'delegation' AND (
      p_delegation IS NULL OR 
      ep.delegation = p_delegation
    ) AND ep.delegation = ANY(v_supervisor_delegations))
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

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_time_requests_created_at 
ON time_requests(created_at);

CREATE INDEX IF NOT EXISTS idx_planner_requests_created_at 
ON planner_requests(created_at);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers_gin 
ON employee_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation_btree 
ON employee_profiles(delegation);

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_filtered_requests TO authenticated;
GRANT EXECUTE ON FUNCTION get_supervisor_filtered_requests TO authenticated;