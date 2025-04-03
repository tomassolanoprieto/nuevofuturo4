-- Drop existing policies first to avoid conflicts
DROP POLICY IF EXISTS "supervisor_access_policy_v2" ON supervisor_profiles;
DROP POLICY IF EXISTS "supervisor_employee_access_policy_v2" ON employee_profiles;

-- Drop existing functions first
DROP FUNCTION IF EXISTS authenticate_supervisor(TEXT, TEXT);
DROP FUNCTION IF EXISTS get_delegation_employees(UUID);
DROP FUNCTION IF EXISTS get_supervisor_info(TEXT);
DROP FUNCTION IF EXISTS supervisor_exists(TEXT);

-- Create comprehensive policy for supervisor access
CREATE POLICY "supervisor_access_policy_v3"
  ON supervisor_profiles
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create policy for supervisor access to employee data
CREATE POLICY "supervisor_employee_access_policy_v3"
  ON employee_profiles
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create improved function to authenticate supervisor
CREATE FUNCTION authenticate_supervisor(
  p_email TEXT,
  p_pin TEXT
)
RETURNS TABLE (
  id UUID,
  email TEXT,
  supervisor_type TEXT,
  work_centers work_center_enum[],
  delegations delegation_enum[],
  company_id UUID,
  is_active BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sp.id,
    sp.email,
    sp.supervisor_type::TEXT,
    sp.work_centers,
    sp.delegations,
    sp.company_id,
    sp.is_active
  FROM supervisor_profiles sp
  WHERE sp.email = p_email 
  AND sp.pin = p_pin
  AND sp.is_active = true
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create improved function to get delegation employees
CREATE FUNCTION get_delegation_employees(p_supervisor_id UUID)
RETURNS TABLE (
  id UUID,
  fiscal_name TEXT,
  email TEXT,
  work_centers work_center_enum[],
  delegation delegation_enum,
  document_type TEXT,
  document_number TEXT,
  job_positions job_position_enum[],
  employee_id TEXT,
  seniority_date DATE,
  is_active BOOLEAN,
  company_id UUID
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ep.id,
    ep.fiscal_name,
    ep.email,
    ep.work_centers,
    ep.delegation,
    ep.document_type,
    ep.document_number,
    ep.job_positions,
    ep.employee_id,
    ep.seniority_date,
    ep.is_active,
    ep.company_id
  FROM employee_profiles ep
  JOIN supervisor_profiles sp ON sp.company_id = ep.company_id
  WHERE sp.id = p_supervisor_id
  AND sp.is_active = true
  AND sp.supervisor_type = 'delegation'
  AND ep.is_active = true
  AND ep.delegation = ANY(sp.delegations)
  ORDER BY ep.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get supervisor info
CREATE FUNCTION get_supervisor_info(p_email TEXT)
RETURNS TABLE (
  id UUID,
  email TEXT,
  supervisor_type TEXT,
  work_centers work_center_enum[],
  delegations delegation_enum[],
  company_id UUID,
  is_active BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sp.id,
    sp.email,
    sp.supervisor_type::TEXT,
    sp.work_centers,
    sp.delegations,
    sp.company_id,
    sp.is_active
  FROM supervisor_profiles sp
  WHERE sp.email = p_email
  AND sp.is_active = true
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if supervisor exists
CREATE FUNCTION supervisor_exists(p_email TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM supervisor_profiles
    WHERE email = p_email
    AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create or replace indexes for better performance
DO $$ 
BEGIN
    -- Drop indexes if they exist
    DROP INDEX IF EXISTS idx_supervisor_profiles_email_pin;
    DROP INDEX IF EXISTS idx_supervisor_profiles_type_active;
    DROP INDEX IF EXISTS idx_employee_profiles_delegation_active;
    
    -- Create new indexes
    IF NOT EXISTS (
        SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = 'idx_supervisor_profiles_email_pin'
    ) THEN
        CREATE INDEX idx_supervisor_profiles_email_pin 
        ON supervisor_profiles(email, pin);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = 'idx_supervisor_profiles_type_active'
    ) THEN
        CREATE INDEX idx_supervisor_profiles_type_active 
        ON supervisor_profiles(supervisor_type, is_active);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = 'idx_employee_profiles_delegation_active'
    ) THEN
        CREATE INDEX idx_employee_profiles_delegation_active 
        ON employee_profiles(delegation, is_active);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = 'idx_supervisor_profiles_email'
    ) THEN
        CREATE INDEX idx_supervisor_profiles_email 
        ON supervisor_profiles(email);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = 'idx_supervisor_profiles_delegations'
    ) THEN
        CREATE INDEX idx_supervisor_profiles_delegations 
        ON supervisor_profiles USING gin(delegations);
    END IF;
END $$;