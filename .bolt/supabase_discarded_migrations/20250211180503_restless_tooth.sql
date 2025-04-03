-- Drop existing policies if they exist
DROP POLICY IF EXISTS "time_requests_access" ON time_requests;
DROP POLICY IF EXISTS "planner_requests_access" ON planner_requests;

-- Create comprehensive policy for time requests
CREATE POLICY "company_time_requests_access"
  ON time_requests
  FOR ALL
  TO authenticated
  USING (
    -- Employee can access their own requests
    employee_id = auth.uid() OR
    -- Company can access their employees' requests
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_requests.employee_id
      AND ep.company_id = auth.uid()
    )
  )
  WITH CHECK (
    -- Employee can create their own requests
    employee_id = auth.uid() OR
    -- Company can manage their employees' requests
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_requests.employee_id
      AND ep.company_id = auth.uid()
    )
  );

-- Create comprehensive policy for planner requests
CREATE POLICY "company_planner_requests_access"
  ON planner_requests
  FOR ALL
  TO authenticated
  USING (
    -- Employee can access their own requests
    employee_id = auth.uid() OR
    -- Company can access their employees' requests
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = planner_requests.employee_id
      AND ep.company_id = auth.uid()
    )
  )
  WITH CHECK (
    -- Employee can create their own requests
    employee_id = auth.uid() OR
    -- Company can manage their employees' requests
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = planner_requests.employee_id
      AND ep.company_id = auth.uid()
    )
  );

-- Create function to get company requests
CREATE OR REPLACE FUNCTION get_company_requests(p_company_id UUID)
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
  
  ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_company_requests(UUID) TO authenticated;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_time_requests_employee_id_status 
ON time_requests(employee_id, status);

CREATE INDEX IF NOT EXISTS idx_planner_requests_employee_id_status 
ON planner_requests(employee_id, status);

CREATE INDEX IF NOT EXISTS idx_time_requests_created_at 
ON time_requests(created_at);

CREATE INDEX IF NOT EXISTS idx_planner_requests_created_at 
ON planner_requests(created_at);