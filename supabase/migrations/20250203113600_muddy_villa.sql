-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view planner requests" ON planner_requests;
DROP POLICY IF EXISTS "Users can create planner requests" ON planner_requests;
DROP POLICY IF EXISTS "Users can update planner requests" ON planner_requests;

-- Create comprehensive policies for planner_requests
CREATE POLICY "Users can view planner requests"
  ON planner_requests
  FOR SELECT
  TO authenticated
  USING (
    employee_id = auth.uid() OR  -- Employee can view their own requests
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = planner_requests.employee_id
      AND ep.company_id = auth.uid()  -- Company can view their employees' requests
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      JOIN employee_profiles ep ON ep.id = planner_requests.employee_id
      WHERE sp.id = auth.uid()
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )  -- Supervisor can view requests from their employees
  );

CREATE POLICY "Users can create planner requests"
  ON planner_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (
    employee_id = auth.uid() OR  -- Employee can create their own requests
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = planner_requests.employee_id
      AND ep.company_id = auth.uid()  -- Company can create requests for their employees
    )
  );

CREATE POLICY "Users can update planner requests"
  ON planner_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = planner_requests.employee_id
      AND ep.company_id = auth.uid()  -- Company can update their employees' requests
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      JOIN employee_profiles ep ON ep.id = planner_requests.employee_id
      WHERE sp.id = auth.uid()
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )  -- Supervisor can update requests from their employees
  );

CREATE POLICY "Users can delete planner requests"
  ON planner_requests
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = planner_requests.employee_id
      AND ep.company_id = auth.uid()  -- Company can delete their employees' requests
    )
  );