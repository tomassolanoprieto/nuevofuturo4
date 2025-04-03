-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Companies can view their employees' requests" ON time_requests;
DROP POLICY IF EXISTS "Companies can view their employees' vacation requests" ON vacation_requests;
DROP POLICY IF EXISTS "Companies can view their employees' absence requests" ON absence_requests;

-- Create policies for time_requests
CREATE POLICY "Users can view time requests"
  ON time_requests
  FOR SELECT
  TO authenticated
  USING (
    employee_id = auth.uid() OR  -- Employee can view their own requests
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_requests.employee_id
      AND ep.company_id = auth.uid()  -- Company can view their employees' requests
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = (
        SELECT company_id FROM employee_profiles ep
        WHERE ep.id = time_requests.employee_id
      )
      AND sp.work_center = (
        SELECT work_center FROM employee_profiles ep
        WHERE ep.id = time_requests.employee_id
      )
    )  -- Supervisor can view requests from their work center
  );

CREATE POLICY "Users can update time requests"
  ON time_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_requests.employee_id
      AND ep.company_id = auth.uid()  -- Company can update their employees' requests
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = (
        SELECT company_id FROM employee_profiles ep
        WHERE ep.id = time_requests.employee_id
      )
      AND sp.work_center = (
        SELECT work_center FROM employee_profiles ep
        WHERE ep.id = time_requests.employee_id
      )
    )  -- Supervisor can update requests from their work center
  );

-- Create policies for vacation_requests
CREATE POLICY "Users can view vacation requests"
  ON vacation_requests
  FOR SELECT
  TO authenticated
  USING (
    employee_id = auth.uid() OR  -- Employee can view their own requests
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = vacation_requests.employee_id
      AND ep.company_id = auth.uid()  -- Company can view their employees' requests
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = (
        SELECT company_id FROM employee_profiles ep
        WHERE ep.id = vacation_requests.employee_id
      )
      AND sp.work_center = (
        SELECT work_center FROM employee_profiles ep
        WHERE ep.id = vacation_requests.employee_id
      )
    )  -- Supervisor can view requests from their work center
  );

CREATE POLICY "Users can update vacation requests"
  ON vacation_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = vacation_requests.employee_id
      AND ep.company_id = auth.uid()  -- Company can update their employees' requests
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = (
        SELECT company_id FROM employee_profiles ep
        WHERE ep.id = vacation_requests.employee_id
      )
      AND sp.work_center = (
        SELECT work_center FROM employee_profiles ep
        WHERE ep.id = vacation_requests.employee_id
      )
    )  -- Supervisor can update requests from their work center
  );

-- Create policies for absence_requests
CREATE POLICY "Users can view absence requests"
  ON absence_requests
  FOR SELECT
  TO authenticated
  USING (
    employee_id = auth.uid() OR  -- Employee can view their own requests
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = absence_requests.employee_id
      AND ep.company_id = auth.uid()  -- Company can view their employees' requests
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = (
        SELECT company_id FROM employee_profiles ep
        WHERE ep.id = absence_requests.employee_id
      )
      AND sp.work_center = (
        SELECT work_center FROM employee_profiles ep
        WHERE ep.id = absence_requests.employee_id
      )
    )  -- Supervisor can view requests from their work center
  );

CREATE POLICY "Users can update absence requests"
  ON absence_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = absence_requests.employee_id
      AND ep.company_id = auth.uid()  -- Company can update their employees' requests
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = (
        SELECT company_id FROM employee_profiles ep
        WHERE ep.id = absence_requests.employee_id
      )
      AND sp.work_center = (
        SELECT work_center FROM employee_profiles ep
        WHERE ep.id = absence_requests.employee_id
      )
    )  -- Supervisor can update requests from their work center
  );