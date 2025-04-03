-- Add company_id foreign key to employee_profiles if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'employee_profiles' 
        AND column_name = 'company_id'
    ) THEN
        ALTER TABLE employee_profiles
        ADD COLUMN company_id UUID REFERENCES company_profiles(id);
    END IF;
END $$;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_company_id 
ON employee_profiles(company_id);

-- Create policy for companies to view their employees
CREATE POLICY "companies_view_employees"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (
    company_id = auth.uid() OR
    id = auth.uid()
  );

-- Create policy for companies to manage their employees
CREATE POLICY "companies_manage_employees"
  ON employee_profiles
  FOR ALL
  TO authenticated
  USING (company_id = auth.uid())
  WITH CHECK (company_id = auth.uid());

-- Enable RLS if not already enabled
ALTER TABLE employee_profiles ENABLE ROW LEVEL SECURITY;