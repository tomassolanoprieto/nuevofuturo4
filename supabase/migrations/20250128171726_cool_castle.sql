-- Add employee_id and seniority_date columns if they don't exist
ALTER TABLE employee_profiles
ADD COLUMN IF NOT EXISTS employee_id TEXT,
ADD COLUMN IF NOT EXISTS seniority_date DATE;

-- Create index for employee_id for better performance
CREATE INDEX IF NOT EXISTS employee_profiles_employee_id_idx ON employee_profiles(employee_id);

-- Create index for seniority_date for better performance
CREATE INDEX IF NOT EXISTS employee_profiles_seniority_date_idx ON employee_profiles(seniority_date);