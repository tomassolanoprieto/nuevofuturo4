-- Drop existing policies if they exist
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "time_requests_access" ON time_requests;
    DROP POLICY IF EXISTS "planner_requests_access" ON planner_requests;
EXCEPTION
    WHEN undefined_object THEN null;
END $$;

-- Create comprehensive policies for requests
CREATE POLICY "time_requests_access"
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
    ) OR
    -- Supervisor can access requests from their work centers/delegations
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp, employee_profiles ep
      WHERE sp.id = auth.uid()
      AND ep.id = time_requests.employee_id
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  )
  WITH CHECK (true);

CREATE POLICY "planner_requests_access"
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
    ) OR
    -- Supervisor can access requests from their work centers/delegations
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp, employee_profiles ep
      WHERE sp.id = auth.uid()
      AND ep.id = planner_requests.employee_id
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  )
  WITH CHECK (true);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_time_requests_employee_id 
ON time_requests(employee_id);

CREATE INDEX IF NOT EXISTS idx_planner_requests_employee_id 
ON planner_requests(employee_id);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_company_id 
ON employee_profiles(company_id);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_company_id 
ON supervisor_profiles(company_id);