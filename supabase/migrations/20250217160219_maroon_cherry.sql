-- Create function to get employees by delegation
CREATE OR REPLACE FUNCTION get_employees_by_delegation(p_delegation delegation_enum)
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
  WHERE ep.delegation = p_delegation
  AND ep.is_active = true
  ORDER BY ep.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get employees by work center
CREATE OR REPLACE FUNCTION get_employees_by_work_center(p_work_center work_center_enum)
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
  WHERE p_work_center = ANY(ep.work_centers)
  AND ep.is_active = true
  ORDER BY ep.fiscal_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get employee count by delegation
CREATE OR REPLACE FUNCTION get_employee_count_by_delegation(p_delegation delegation_enum)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM employee_profiles
    WHERE delegation = p_delegation
    AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get employee count by work center
CREATE OR REPLACE FUNCTION get_employee_count_by_work_center(p_work_center work_center_enum)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM employee_profiles
    WHERE p_work_center = ANY(work_centers)
    AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to all users
GRANT EXECUTE ON FUNCTION get_employees_by_delegation TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_employees_by_work_center TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_employee_count_by_delegation TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_employee_count_by_work_center TO PUBLIC;