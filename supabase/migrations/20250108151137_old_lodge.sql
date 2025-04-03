/*
  # Add absence requests table

  1. New Tables
    - `absence_requests`
      - `id` (uuid, primary key)
      - `employee_id` (uuid, references employee_profiles)
      - `reason` (text, enum)
      - `start_datetime` (timestamptz)
      - `end_datetime` (timestamptz)
      - `comment` (text)
      - `status` (text, enum)
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS
    - Add policies for employees and companies
*/

CREATE TABLE IF NOT EXISTS absence_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES employee_profiles(id),
  reason TEXT NOT NULL CHECK (reason IN (
    'Baja Médica',
    'Otros Motivos',
    'Asuntos personales/familiares',
    'Día libre',
    'Examen o prueba académica',
    'Mudanza o traslado',
    'Vacaciones no pagadas',
    'Visita o prueba médica',
    'Teletrabajo'
  )),
  start_datetime TIMESTAMPTZ NOT NULL,
  end_datetime TIMESTAMPTZ NOT NULL,
  comment TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT valid_datetime_range CHECK (end_datetime >= start_datetime)
);

-- Enable RLS
ALTER TABLE absence_requests ENABLE ROW LEVEL SECURITY;

-- Employees can view and create their own requests
CREATE POLICY "Employees can view their own absence requests"
  ON absence_requests
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = employee_id OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.company_id = auth.uid()
      AND ep.id = absence_requests.employee_id
    )
  );

CREATE POLICY "Employees can create their own absence requests"
  ON absence_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = employee_id);

-- Companies can manage their employees' requests
CREATE POLICY "Companies can update absence requests"
  ON absence_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.company_id = auth.uid()
      AND ep.id = absence_requests.employee_id
    )
  );