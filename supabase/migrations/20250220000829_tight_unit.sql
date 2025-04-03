-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS sync_employee_with_company_trigger ON employee_profiles;
DROP TRIGGER IF EXISTS sync_supervisor_with_company_trigger ON supervisor_profiles;
DROP FUNCTION IF EXISTS sync_employee_with_company();
DROP FUNCTION IF EXISTS sync_supervisor_with_company();

-- Create improved employee sync function
CREATE OR REPLACE FUNCTION sync_employee_with_company()
RETURNS TRIGGER AS $$
DECLARE
  v_company_id UUID;
  v_claims JSONB;
  v_user_role TEXT;
BEGIN
  -- Try to get JWT claims safely
  BEGIN
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  EXCEPTION
    WHEN OTHERS THEN
      v_claims := NULL;
  END;

  -- Get user role from claims or auth metadata
  IF v_claims IS NOT NULL AND v_claims->>'role' IS NOT NULL THEN
    v_user_role := v_claims->>'role';
  ELSE
    -- Try to get role from auth.users
    SELECT raw_app_meta_data->>'role' INTO v_user_role
    FROM auth.users
    WHERE id = auth.uid();
  END IF;

  -- If user is a company, use their ID directly
  IF v_user_role = 'company' THEN
    NEW.company_id := auth.uid();
  ELSE
    -- Try to get company ID from supervisor's company
    SELECT company_id INTO v_company_id
    FROM supervisor_profiles
    WHERE id = auth.uid()
    AND is_active = true;

    -- If no company ID found, try to get it from auth.users
    IF v_company_id IS NULL THEN
      SELECT id INTO v_company_id
      FROM company_profiles
      WHERE id = auth.uid();
    END IF;

    -- If still no company ID found, raise exception
    IF v_company_id IS NULL THEN
      RAISE EXCEPTION 'No se encontró la empresa asociada';
    END IF;

    NEW.company_id := v_company_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create improved supervisor sync function
CREATE OR REPLACE FUNCTION sync_supervisor_with_company()
RETURNS TRIGGER AS $$
DECLARE
  v_company_id UUID;
  v_claims JSONB;
  v_user_role TEXT;
BEGIN
  -- Try to get JWT claims safely
  BEGIN
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  EXCEPTION
    WHEN OTHERS THEN
      v_claims := NULL;
  END;

  -- Get user role from claims or auth metadata
  IF v_claims IS NOT NULL AND v_claims->>'role' IS NOT NULL THEN
    v_user_role := v_claims->>'role';
  ELSE
    -- Try to get role from auth.users
    SELECT raw_app_meta_data->>'role' INTO v_user_role
    FROM auth.users
    WHERE id = auth.uid();
  END IF;

  -- If user is a company, use their ID directly
  IF v_user_role = 'company' THEN
    NEW.company_id := auth.uid();
  ELSE
    -- Try to get company ID from supervisor's company
    SELECT company_id INTO v_company_id
    FROM supervisor_profiles
    WHERE id = auth.uid()
    AND is_active = true;

    -- If no company ID found, try to get it from auth.users
    IF v_company_id IS NULL THEN
      SELECT id INTO v_company_id
      FROM company_profiles
      WHERE id = auth.uid();
    END IF;

    -- If still no company ID found, raise exception
    IF v_company_id IS NULL THEN
      RAISE EXCEPTION 'No se encontró la empresa asociada';
    END IF;

    NEW.company_id := v_company_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
CREATE TRIGGER sync_employee_with_company_trigger
  BEFORE INSERT ON employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_employee_with_company();

CREATE TRIGGER sync_supervisor_with_company_trigger
  BEFORE INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_supervisor_with_company();

-- Create function to get company ID for supervisor
CREATE OR REPLACE FUNCTION get_supervisor_company_id(p_supervisor_id UUID)
RETURNS UUID AS $$
  SELECT COALESCE(
    -- Try to get from supervisor profiles first
    (SELECT company_id
     FROM supervisor_profiles
     WHERE id = p_supervisor_id
     AND is_active = true),
    -- If not found, try to get from company profiles
    (SELECT id
     FROM company_profiles
     WHERE id = p_supervisor_id)
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- Create function to validate supervisor company access
CREATE OR REPLACE FUNCTION validate_supervisor_company_access(
  p_supervisor_id UUID,
  p_company_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM supervisor_profiles
    WHERE id = p_supervisor_id
    AND company_id = p_company_id
    AND is_active = true
  ) OR EXISTS (
    SELECT 1
    FROM company_profiles
    WHERE id = p_supervisor_id
    AND id = p_company_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_company_id 
ON employee_profiles(company_id);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_company_id 
ON supervisor_profiles(company_id);

CREATE INDEX IF NOT EXISTS idx_auth_users_role 
ON auth.users((raw_app_meta_data->>'role'));

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_supervisor_company_id TO anon, PUBLIC;
GRANT EXECUTE ON FUNCTION validate_supervisor_company_access TO anon, PUBLIC;