-- Drop existing table if exists
DROP TABLE IF EXISTS supervisor_profiles CASCADE;

-- Create supervisor_profiles table with all required columns
CREATE TABLE supervisor_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fiscal_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  country TEXT NOT NULL DEFAULT 'España',
  timezone TEXT NOT NULL DEFAULT 'Europe/Madrid',
  company_id UUID REFERENCES company_profiles(id),
  is_active BOOLEAN DEFAULT true,
  document_type TEXT CHECK (document_type IN ('DNI', 'NIE', 'Pasaporte')),
  document_number TEXT,
  work_centers work_center_enum[] DEFAULT '{}',
  delegations delegation_enum[] DEFAULT '{}',
  supervisor_type TEXT CHECK (supervisor_type IN ('center', 'delegation')),
  pin TEXT NOT NULL CHECK (pin ~ '^\d{6}$'),
  employee_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT valid_supervisor_assignments CHECK (
    (supervisor_type = 'center' AND array_length(work_centers, 1) > 0 AND array_length(delegations, 1) IS NULL) OR
    (supervisor_type = 'delegation' AND array_length(delegations, 1) > 0 AND array_length(work_centers, 1) IS NULL)
  )
);

-- Enable RLS
ALTER TABLE supervisor_profiles ENABLE ROW LEVEL SECURITY;

-- Create policy for supervisor access
CREATE POLICY "supervisor_access_policy"
  ON supervisor_profiles
  FOR ALL
  TO authenticated
  USING (
    id = auth.uid() OR 
    company_id = auth.uid()
  )
  WITH CHECK (company_id = auth.uid());

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_email ON supervisor_profiles(email);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_company_id ON supervisor_profiles(company_id);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_is_active ON supervisor_profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_work_centers ON supervisor_profiles USING gin(work_centers);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_delegations ON supervisor_profiles USING gin(delegations);
CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_supervisor_type ON supervisor_profiles(supervisor_type);

-- Create function to get supervisor info
CREATE OR REPLACE FUNCTION get_supervisor_info(p_email TEXT)
RETURNS TABLE (
  id UUID,
  fiscal_name TEXT,
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
    sp.fiscal_name,
    sp.email,
    sp.supervisor_type,
    sp.work_centers,
    sp.delegations,
    sp.company_id,
    sp.is_active
  FROM supervisor_profiles sp
  WHERE sp.email = p_email
  AND sp.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to validate supervisor credentials
CREATE OR REPLACE FUNCTION validate_supervisor_credentials(
  p_email TEXT,
  p_pin TEXT
)
RETURNS TABLE (
  id UUID,
  fiscal_name TEXT,
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
    sp.fiscal_name,
    sp.email,
    sp.supervisor_type,
    sp.work_centers,
    sp.delegations,
    sp.company_id,
    sp.is_active
  FROM supervisor_profiles sp
  WHERE sp.email = p_email
  AND sp.pin = p_pin
  AND sp.is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Credenciales inválidas';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_supervisor_info TO authenticated;
GRANT EXECUTE ON FUNCTION validate_supervisor_credentials TO authenticated;