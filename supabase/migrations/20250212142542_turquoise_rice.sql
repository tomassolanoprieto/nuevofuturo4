-- Create function to get company requests
CREATE OR REPLACE FUNCTION get_company_requests(
  p_company_id UUID,
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ
)
RETURNS TABLE (
  request_id UUID,
  request_type TEXT,
  request_status TEXT,
  created_at TIMESTAMPTZ,
  employee_id UUID,
  employee_name TEXT,
  employee_email TEXT,
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
    jsonb_build_object(
      'datetime', tr.datetime,
      'entry_type', tr.entry_type,
      'comment', tr.comment
    ) as details
  FROM time_requests tr
  JOIN employee_profiles ep ON ep.id = tr.employee_id
  WHERE ep.company_id = p_company_id
  AND (
    p_start_date IS NULL 
    OR tr.created_at >= p_start_date
  )
  AND (
    p_end_date IS NULL 
    OR tr.created_at <= p_end_date
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
    jsonb_build_object(
      'planner_type', pr.planner_type,
      'start_date', pr.start_date,
      'end_date', pr.end_date,
      'comment', pr.comment
    ) as details
  FROM planner_requests pr
  JOIN employee_profiles ep ON ep.id = pr.employee_id
  WHERE ep.company_id = p_company_id
  AND (
    p_start_date IS NULL 
    OR pr.created_at >= p_start_date
  )
  AND (
    p_end_date IS NULL 
    OR pr.created_at <= p_end_date
  )
  ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_time_requests_created_at 
ON time_requests(created_at);

CREATE INDEX IF NOT EXISTS idx_planner_requests_created_at 
ON planner_requests(created_at);

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_company_requests TO authenticated;