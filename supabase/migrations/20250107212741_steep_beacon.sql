/*
  # Add dual-role support for company users
  
  1. Changes
    - Add role column to auth profiles to distinguish between company and employee roles
    - Add policies to allow company users to also have employee profiles
    
  2. Security
    - Update RLS policies to handle dual-role access
*/

-- Add role column to both profile tables if not exists
ALTER TABLE company_profiles
ADD COLUMN IF NOT EXISTS roles TEXT[] DEFAULT ARRAY['company'];

ALTER TABLE employee_profiles
ADD COLUMN IF NOT EXISTS roles TEXT[] DEFAULT ARRAY['employee'];

-- Update policies for employee profiles to allow company users
DROP POLICY IF EXISTS "Users can view own employee profile" ON employee_profiles;
CREATE POLICY "Users can view own employee profile"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = id OR 
    EXISTS (
      SELECT 1 FROM company_profiles 
      WHERE company_profiles.id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update own employee profile" ON employee_profiles;
CREATE POLICY "Users can update own employee profile"
  ON employee_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own employee profile" ON employee_profiles;
CREATE POLICY "Users can insert own employee profile"
  ON employee_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = id OR
    EXISTS (
      SELECT 1 FROM company_profiles 
      WHERE company_profiles.id = auth.uid()
    )
  );