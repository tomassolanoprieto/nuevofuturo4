-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view planner requests" ON planner_requests;
DROP POLICY IF EXISTS "Users can create planner requests" ON planner_requests;
DROP POLICY IF EXISTS "Users can update planner requests" ON planner_requests;

-- Create planner_requests table if it doesn't exist
CREATE TABLE IF NOT EXISTS planner_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES employee_profiles(id),
  planner_type TEXT NOT NULL CHECK (
    planner_type IN (
      'Horas compensadas',
      'Horas vacaciones',
      'Horas asuntos propios'
    )
  ),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  comment TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT valid_date_range CHECK (end_date >= start_date)
);

-- Enable RLS
ALTER TABLE planner_requests ENABLE ROW LEVEL SECURITY;

-- Create policies for planner_requests
CREATE POLICY "Users can view planner requests"
  ON planner_requests
  FOR SELECT
  TO authenticated
  USING (
    employee_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = planner_requests.employee_id
      AND ep.company_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp, employee_profiles ep
      WHERE sp.id = auth.uid()
      AND ep.id = planner_requests.employee_id
      AND sp.company_id = ep.company_id
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  );

CREATE POLICY "Users can create planner requests"
  ON planner_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = employee_id);

CREATE POLICY "Users can update planner requests"
  ON planner_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = planner_requests.employee_id
      AND ep.company_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp, employee_profiles ep
      WHERE sp.id = auth.uid()
      AND ep.id = planner_requests.employee_id
      AND sp.company_id = ep.company_id
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  );

-- Enable realtime for planner_requests
ALTER TABLE planner_requests REPLICA IDENTITY FULL;