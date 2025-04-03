-- Drop dependent policies first
DROP POLICY IF EXISTS "Users can view time requests" ON time_requests;
DROP POLICY IF EXISTS "Users can update time requests" ON time_requests;
DROP POLICY IF EXISTS "Users can view vacation requests" ON vacation_requests;
DROP POLICY IF EXISTS "Users can update vacation requests" ON vacation_requests;
DROP POLICY IF EXISTS "Users can view absence requests" ON absence_requests;
DROP POLICY IF EXISTS "Users can update absence requests" ON absence_requests;

-- Create supervisor type enum
CREATE TYPE supervisor_type_enum AS ENUM ('delegation', 'center');

-- First add the new columns as nullable
ALTER TABLE supervisor_profiles
DROP COLUMN IF EXISTS work_centers CASCADE,
ADD COLUMN supervisor_type supervisor_type_enum,
ADD COLUMN work_centers work_center_enum[] DEFAULT '{}',
ADD COLUMN delegations delegation_enum[] DEFAULT '{}';

-- Update existing rows with default values
UPDATE supervisor_profiles
SET supervisor_type = 'center'
WHERE supervisor_type IS NULL;

-- Now make supervisor_type NOT NULL
ALTER TABLE supervisor_profiles
ALTER COLUMN supervisor_type SET NOT NULL;

-- Add constraint to ensure either work_centers or delegations is not empty based on type
ALTER TABLE supervisor_profiles
ADD CONSTRAINT valid_supervisor_assignments CHECK (
  (supervisor_type = 'center' AND array_length(work_centers, 1) > 0 AND array_length(delegations, 1) IS NULL) OR
  (supervisor_type = 'delegation' AND array_length(delegations, 1) > 0 AND array_length(work_centers, 1) IS NULL)
);

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own supervisor profile" ON supervisor_profiles;
DROP POLICY IF EXISTS "Users can update own supervisor profile" ON supervisor_profiles;
DROP POLICY IF EXISTS "Users can insert supervisor profile" ON supervisor_profiles;
DROP POLICY IF EXISTS "Supervisors can view employee data" ON employee_profiles;

-- Create new policies that consider both types of supervisors
CREATE POLICY "Users can view own supervisor profile"
  ON supervisor_profiles
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = id OR 
    EXISTS (
      SELECT 1 FROM company_profiles 
      WHERE company_profiles.id = auth.uid()
    )
  );

CREATE POLICY "Users can update own supervisor profile"
  ON supervisor_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can insert supervisor profile"
  ON supervisor_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = id OR
    EXISTS (
      SELECT 1 FROM company_profiles 
      WHERE company_profiles.id = auth.uid()
    )
  );

-- Create new policy for employee data access
CREATE POLICY "Supervisors can view employee data"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = employee_profiles.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND employee_profiles.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND employee_profiles.delegation = ANY(sp.delegations))
      )
    )
  );

-- Recreate policies for time requests
CREATE POLICY "Users can view time requests"
  ON time_requests
  FOR SELECT
  TO authenticated
  USING (
    employee_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_requests.employee_id
      AND ep.company_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp, employee_profiles ep
      WHERE sp.id = auth.uid()
      AND ep.id = time_requests.employee_id
      AND sp.company_id = ep.company_id
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  );

CREATE POLICY "Users can update time requests"
  ON time_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_requests.employee_id
      AND ep.company_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp, employee_profiles ep
      WHERE sp.id = auth.uid()
      AND ep.id = time_requests.employee_id
      AND sp.company_id = ep.company_id
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  );

-- Recreate policies for vacation requests
CREATE POLICY "Users can view vacation requests"
  ON vacation_requests
  FOR SELECT
  TO authenticated
  USING (
    employee_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = vacation_requests.employee_id
      AND ep.company_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp, employee_profiles ep
      WHERE sp.id = auth.uid()
      AND ep.id = vacation_requests.employee_id
      AND sp.company_id = ep.company_id
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  );

CREATE POLICY "Users can update vacation requests"
  ON vacation_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = vacation_requests.employee_id
      AND ep.company_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp, employee_profiles ep
      WHERE sp.id = auth.uid()
      AND ep.id = vacation_requests.employee_id
      AND sp.company_id = ep.company_id
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  );

-- Recreate policies for absence requests
CREATE POLICY "Users can view absence requests"
  ON absence_requests
  FOR SELECT
  TO authenticated
  USING (
    employee_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = absence_requests.employee_id
      AND ep.company_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp, employee_profiles ep
      WHERE sp.id = auth.uid()
      AND ep.id = absence_requests.employee_id
      AND sp.company_id = ep.company_id
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  );

CREATE POLICY "Users can update absence requests"
  ON absence_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = absence_requests.employee_id
      AND ep.company_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp, employee_profiles ep
      WHERE sp.id = auth.uid()
      AND ep.id = absence_requests.employee_id
      AND sp.company_id = ep.company_id
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  );