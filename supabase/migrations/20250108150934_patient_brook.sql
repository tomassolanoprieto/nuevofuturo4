/*
  # Add vacation requests table

  1. New Tables
    - `vacation_requests`
      - `id` (uuid, primary key)
      - `employee_id` (uuid, references employee_profiles)
      - `start_date` (date)
      - `end_date` (date)
      - `comment` (text)
      - `status` (text, enum)
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS
    - Add policies for employees and companies
*/

CREATE TABLE IF NOT EXISTS vacation_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES employee_profiles(id),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  comment TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT valid_date_range CHECK (end_date >= start_date)
);

-- Enable RLS
ALTER TABLE vacation_requests ENABLE ROW LEVEL SECURITY;

-- Employees can view and create their own requests
CREATE POLICY "Employees can view their own vacation requests"
  ON vacation_requests
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = employee_id OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.company_id = auth.uid()
      AND ep.id = vacation_requests.employee_id
    )
  );

CREATE POLICY "Employees can create their own vacation requests"
  ON vacation_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = employee_id);

-- Companies can manage their employees' requests
CREATE POLICY "Companies can update vacation requests"
  ON vacation_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.company_id = auth.uid()
      AND ep.id = vacation_requests.employee_id
    )
  );