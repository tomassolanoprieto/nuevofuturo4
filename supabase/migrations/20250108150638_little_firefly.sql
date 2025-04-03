/*
  # Add time requests table

  1. New Tables
    - `time_requests`
      - `id` (uuid, primary key)
      - `employee_id` (uuid, references employee_profiles)
      - `datetime` (timestamptz)
      - `entry_type` (text, enum)
      - `comment` (text)
      - `status` (text, enum)
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on `time_requests` table
    - Add policies for employees to manage their requests
    - Add policies for companies to view/manage their employees' requests
*/

CREATE TABLE IF NOT EXISTS time_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES employee_profiles(id),
  datetime TIMESTAMPTZ NOT NULL,
  entry_type TEXT NOT NULL CHECK (entry_type IN ('clock_in', 'break_start', 'break_end', 'clock_out')),
  comment TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE time_requests ENABLE ROW LEVEL SECURITY;

-- Employees can view and create their own requests
CREATE POLICY "Employees can view their own requests"
  ON time_requests
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = employee_id OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.company_id = auth.uid()
      AND ep.id = time_requests.employee_id
    )
  );

CREATE POLICY "Employees can create their own requests"
  ON time_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = employee_id);

-- Companies can view and manage their employees' requests
CREATE POLICY "Companies can update their employees' requests"
  ON time_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.company_id = auth.uid()
      AND ep.id = time_requests.employee_id
    )
  );