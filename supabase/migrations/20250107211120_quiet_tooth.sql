/*
  # Time Tracking System Tables

  1. New Tables
    - Add company_id to employee_profiles
    - work_centers - Company work locations
    - time_entries - Employee time clock entries
    - manual_entries - Manual time entries by company admins
  
  2. Security
    - Enable RLS on all tables
    - Add policies for company access
*/

-- Add company_id to employee_profiles
ALTER TABLE employee_profiles 
ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES company_profiles(id);

CREATE TABLE IF NOT EXISTS work_centers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES company_profiles(id),
  name TEXT NOT NULL,
  address TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS time_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES employee_profiles(id),
  work_center_id UUID REFERENCES work_centers(id),
  entry_type TEXT NOT NULL CHECK (entry_type IN ('clock_in', 'break_start', 'break_end', 'clock_out')),
  timestamp TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS manual_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES employee_profiles(id),
  work_center_id UUID REFERENCES work_centers(id),
  clock_in TIMESTAMPTZ NOT NULL,
  break_start TIMESTAMPTZ,
  break_end TIMESTAMPTZ,
  clock_out TIMESTAMPTZ,
  created_by UUID REFERENCES company_profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE work_centers ENABLE ROW LEVEL SECURITY;
ALTER TABLE time_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE manual_entries ENABLE ROW LEVEL SECURITY;

-- Policies for work centers
CREATE POLICY "Companies can view their work centers"
  ON work_centers FOR SELECT
  TO authenticated
  USING (company_id = auth.uid());

CREATE POLICY "Companies can insert their work centers"
  ON work_centers FOR INSERT
  TO authenticated
  WITH CHECK (company_id = auth.uid());

-- Policies for time entries
CREATE POLICY "Companies can view their employees time entries"
  ON time_entries FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = employee_id
      AND ep.company_id = auth.uid()
    )
  );

-- Policies for manual entries
CREATE POLICY "Companies can view their manual entries"
  ON manual_entries FOR SELECT
  TO authenticated
  USING (created_by = auth.uid());

CREATE POLICY "Companies can insert manual entries"
  ON manual_entries FOR INSERT
  TO authenticated
  WITH CHECK (created_by = auth.uid());