-- Create work_centers enum
CREATE TYPE work_center_enum AS ENUM (
  'Pilillas',
  'Avenida de América',
  'Ventas',
  'Ibiza',
  'Pasamonte',
  'Miguel Hernandez',
  'Valdebernardo',
  'Paseo Extremadura',
  'Humanitarias',
  'Gabriel Usera',
  'Cuevas Almanzora',
  'Alcobendas'
);

-- Create delegations enum
CREATE TYPE delegation_enum AS ENUM (
  'Santander',
  'Madrid',
  'Málaga',
  'Álava',
  'Guipúzcoa',
  'Burgos',
  'Palencia',
  'Valladolid',
  'Alicante',
  'Murcia',
  'Cádiz',
  'Córdoba',
  'Campo Gibraltar',
  'Sevilla'
);

-- First drop the existing policies that depend on work_center
DROP POLICY IF EXISTS "Users can view time requests" ON time_requests;
DROP POLICY IF EXISTS "Users can update time requests" ON time_requests;
DROP POLICY IF EXISTS "Users can view vacation requests" ON vacation_requests;
DROP POLICY IF EXISTS "Users can update vacation requests" ON vacation_requests;
DROP POLICY IF EXISTS "Users can view absence requests" ON absence_requests;
DROP POLICY IF EXISTS "Users can update absence requests" ON absence_requests;

-- Add new columns to employee_profiles
ALTER TABLE employee_profiles
ADD COLUMN IF NOT EXISTS work_centers work_center_enum[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS delegation delegation_enum;

-- Add work_centers array to supervisor_profiles if not exists
ALTER TABLE supervisor_profiles
ADD COLUMN IF NOT EXISTS work_centers work_center_enum[] DEFAULT '{}';

-- Migrate data from work_center to work_centers array
UPDATE employee_profiles 
SET work_centers = ARRAY[work_center::work_center_enum]
WHERE work_center IS NOT NULL 
AND work_centers IS NULL;

-- Now we can safely drop the work_center column
ALTER TABLE employee_profiles
DROP COLUMN IF EXISTS work_center;

-- Recreate the policies with updated logic for work_centers array
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
      AND ep.work_centers && sp.work_centers
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
      AND ep.work_centers && sp.work_centers
    )
  );

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
      AND ep.work_centers && sp.work_centers
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
      AND ep.work_centers && sp.work_centers
    )
  );

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
      AND ep.work_centers && sp.work_centers
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
      AND ep.work_centers && sp.work_centers
    )
  );