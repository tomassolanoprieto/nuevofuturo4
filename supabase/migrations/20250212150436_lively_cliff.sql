-- Add delegations column to supervisor_profiles if it doesn't exist
ALTER TABLE supervisor_profiles
ADD COLUMN IF NOT EXISTS delegations delegation_enum[] DEFAULT '{}';

-- Create index for delegations
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_delegations 
ON supervisor_profiles USING gin(delegations);

-- Create function to get supervisors by delegation
CREATE OR REPLACE FUNCTION get_delegation_supervisors(p_delegation delegation_enum)
RETURNS TABLE (
  id UUID,
  fiscal_name TEXT,
  email TEXT,
  phone TEXT,
  document_type TEXT,
  document_number TEXT,
  supervisor_type TEXT,
  work_centers work_center_enum[],
  delegations delegation_enum[],
  is_active BOOLEAN,
  company_id UUID
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sp.id,
    sp.fiscal_name,
    sp.email,
    sp.phone,
    sp.document_type,
    sp.document_number,
    sp.supervisor_type::TEXT,
    sp.work_centers,
    sp.delegations,
    sp.is_active,
    sp.company_id
  FROM supervisor_profiles sp
  WHERE p_delegation = ANY(sp.delegations)
  AND sp.is_active = true
  AND sp.supervisor_type = 'delegation'
  ORDER BY sp.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to validate supervisor delegations
CREATE OR REPLACE FUNCTION validate_supervisor_delegations(
  p_supervisor_id UUID,
  p_delegations delegation_enum[]
)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM supervisor_profiles sp
    WHERE sp.id = p_supervisor_id
    AND sp.is_active = true
    AND sp.supervisor_type = 'delegation'
    AND sp.delegations && p_delegations
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_delegation_supervisors TO authenticated;
GRANT EXECUTE ON FUNCTION validate_supervisor_delegations TO authenticated;