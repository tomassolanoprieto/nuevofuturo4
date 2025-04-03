-- Drop existing policies first to avoid conflicts
DROP POLICY IF EXISTS "companies_view_employees" ON employee_profiles;
DROP POLICY IF EXISTS "companies_manage_employees" ON employee_profiles;
DROP POLICY IF EXISTS "supervisor_employee_access_v2" ON employee_profiles;
DROP POLICY IF EXISTS "employee_profiles_access_policy_v7" ON employee_profiles;

-- Drop existing functions first
DROP FUNCTION IF EXISTS get_company_employees(UUID);
DROP FUNCTION IF EXISTS get_supervisor_center_employees(UUID);
DROP FUNCTION IF EXISTS get_supervisor_delegation_employees(UUID);

-- Ensure company_id exists and is properly constrained
ALTER TABLE employee_profiles
ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES company_profiles(id);

-- Create comprehensive policies for employee access

-- Company access policy
CREATE POLICY "company_employee_access"
  ON employee_profiles
  FOR ALL
  TO authenticated
  USING (
    -- Company can access their own employees
    company_id = auth.uid() OR
    -- Employee can access their own profile
    id = auth.uid() OR
    -- Supervisor can access employees based on work center or delegation
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = employee_profiles.company_id
      AND sp.is_active = true
      AND (
        -- Center supervisor access
        (sp.supervisor_type = 'center' AND employee_profiles.work_centers && sp.work_centers) OR
        -- Delegation supervisor access
        (sp.supervisor_type = 'delegation' AND employee_profiles.delegation = ANY(sp.delegations))
      )
    )
  )
  WITH CHECK (
    -- Only companies can modify employee data
    company_id = auth.uid()
  );

-- Create function to get employees for company
CREATE FUNCTION get_company_employees_v1(company_uid UUID)
RETURNS SETOF employee_profiles
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT *
  FROM employee_profiles
  WHERE company_id = company_uid
  AND is_active = true;
$$;

-- Create function to get employees for supervisor center
CREATE FUNCTION get_supervisor_center_employees_v1(supervisor_uid UUID)
RETURNS SETOF employee_profiles
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT ep.*
  FROM employee_profiles ep
  JOIN supervisor_profiles sp ON sp.company_id = ep.company_id
  WHERE sp.id = supervisor_uid
  AND sp.is_active = true
  AND sp.supervisor_type = 'center'
  AND ep.is_active = true
  AND ep.work_centers && sp.work_centers;
$$;

-- Create function to get employees for supervisor delegation
CREATE FUNCTION get_supervisor_delegation_employees_v1(supervisor_uid UUID)
RETURNS SETOF employee_profiles
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT ep.*
  FROM employee_profiles ep
  JOIN supervisor_profiles sp ON sp.company_id = ep.company_id
  WHERE sp.id = supervisor_uid
  AND sp.is_active = true
  AND sp.supervisor_type = 'delegation'
  AND ep.is_active = true
  AND ep.delegation = ANY(sp.delegations);
$$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_company_id ON employee_profiles(company_id);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers ON employee_profiles USING gin(work_centers);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation ON employee_profiles(delegation);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_is_active ON employee_profiles(is_active);