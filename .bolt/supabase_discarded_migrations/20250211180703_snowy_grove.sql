-- Drop existing function
DROP FUNCTION IF EXISTS get_company_requests(UUID);

-- Create improved company requests function with date filtering
CREATE OR REPLACE FUNCTION get_company_requests(
  p_company_id UUID,
  p_start_date TIMESTAMPTZ DEFAULT NULL,
  p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
  request_id UUID,
  employee_id UUID,
  employee_name TEXT,
  employee_email TEXT,
  request_type TEXT,
  request_status TEXT,
  created_at TIMESTAMPTZ,
  details JSONB
) AS $$
BEGIN
  -- Return combined time and planner requests
  RETURN QUERY
  -- Time requests
  SELECT 
    tr.id,
    tr.employee_id,
    ep.fiscal_name,
    ep.email,
    'time'::TEXT as request_type,
    tr.status,
    tr.created_at,
    jsonb_build_object(
      'datetime', tr.datetime,
      'entry_type', tr.entry_type,
      'comment', tr.comment
    ) as details
  FROM time_requests tr
  JOIN employee_profiles ep ON ep.id = tr.employee_id
  WHERE ep.company_id = p_company_id
  AND (p_start_date IS NULL OR tr.created_at >= p_start_date)
  AND (p_end_date IS NULL OR tr.created_at <= p_end_date)
  
  UNION ALL
  
  -- Planner requests
  SELECT 
    pr.id,
    pr.employee_id,
    ep.fiscal_name,
    ep.email,
    'planner'::TEXT as request_type,
    pr.status,
    pr.created_at,
    jsonb_build_object(
      'planner_type', pr.planner_type,
      'start_date', pr.start_date,
      'end_date', pr.end_date,
      'comment', pr.comment
    ) as details
  FROM planner_requests pr
  JOIN employee_profiles ep ON ep.id = pr.employee_id
  WHERE ep.company_id = p_company_id
  AND (p_start_date IS NULL OR pr.created_at >= p_start_date)
  AND (p_end_date IS NULL OR pr.created_at <= p_end_date)
  
  ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_company_requests(UUID, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;

-- Create indexes for better performance if they don't exist
CREATE INDEX IF NOT EXISTS idx_time_requests_created_at 
ON time_requests(created_at);

CREATE INDEX IF NOT EXISTS idx_planner_requests_created_at 
ON planner_requests(created_at);