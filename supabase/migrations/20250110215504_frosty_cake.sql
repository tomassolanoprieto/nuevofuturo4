/*
  # Work Schedules Schema

  1. New Tables
    - `work_schedules`: Stores company work schedules
      - `id` (uuid, primary key)
      - `name` (text)
      - `type` (text: regular, special)
      - `company_id` (uuid, references company_profiles)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

    - `schedule_shifts`: Stores shifts for each schedule
      - `id` (uuid, primary key)
      - `schedule_id` (uuid, references work_schedules)
      - `day_of_week` (integer, 0-6)
      - `start_time` (time)
      - `end_time` (time)
      - `break_start` (time)
      - `break_end` (time)
      - `created_at` (timestamptz)

    - `schedule_assignments`: Assigns schedules to employees
      - `id` (uuid, primary key)
      - `employee_id` (uuid, references employee_profiles)
      - `schedule_id` (uuid, references work_schedules)
      - `start_date` (date)
      - `end_date` (date)
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on all tables
    - Add policies for company access
*/

-- Create work_schedules table
CREATE TABLE IF NOT EXISTS work_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('regular', 'special')),
  company_id UUID REFERENCES company_profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create schedule_shifts table
CREATE TABLE IF NOT EXISTS schedule_shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID REFERENCES work_schedules(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  break_start TIME,
  break_end TIME,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT valid_times CHECK (
    start_time < end_time AND
    (break_start IS NULL OR break_end IS NULL OR break_start < break_end) AND
    (break_start IS NULL OR break_start > start_time) AND
    (break_end IS NULL OR break_end < end_time)
  )
);

-- Create schedule_assignments table
CREATE TABLE IF NOT EXISTS schedule_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES employee_profiles(id) ON DELETE CASCADE,
  schedule_id UUID REFERENCES work_schedules(id) ON DELETE CASCADE,
  start_date DATE NOT NULL,
  end_date DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT valid_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

-- Enable RLS
ALTER TABLE work_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedule_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedule_assignments ENABLE ROW LEVEL SECURITY;

-- Policies for work_schedules
CREATE POLICY "Companies can view their schedules"
  ON work_schedules
  FOR SELECT
  TO authenticated
  USING (company_id = auth.uid());

CREATE POLICY "Companies can create schedules"
  ON work_schedules
  FOR INSERT
  TO authenticated
  WITH CHECK (company_id = auth.uid());

CREATE POLICY "Companies can update their schedules"
  ON work_schedules
  FOR UPDATE
  TO authenticated
  USING (company_id = auth.uid());

CREATE POLICY "Companies can delete their schedules"
  ON work_schedules
  FOR DELETE
  TO authenticated
  USING (company_id = auth.uid());

-- Policies for schedule_shifts
CREATE POLICY "Companies can view shifts in their schedules"
  ON schedule_shifts
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM work_schedules
      WHERE work_schedules.id = schedule_id
      AND work_schedules.company_id = auth.uid()
    )
  );

CREATE POLICY "Companies can create shifts in their schedules"
  ON schedule_shifts
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM work_schedules
      WHERE work_schedules.id = schedule_id
      AND work_schedules.company_id = auth.uid()
    )
  );

CREATE POLICY "Companies can update shifts in their schedules"
  ON schedule_shifts
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM work_schedules
      WHERE work_schedules.id = schedule_id
      AND work_schedules.company_id = auth.uid()
    )
  );

CREATE POLICY "Companies can delete shifts in their schedules"
  ON schedule_shifts
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM work_schedules
      WHERE work_schedules.id = schedule_id
      AND work_schedules.company_id = auth.uid()
    )
  );

-- Policies for schedule_assignments
CREATE POLICY "Companies can view assignments in their schedules"
  ON schedule_assignments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM work_schedules
      WHERE work_schedules.id = schedule_id
      AND work_schedules.company_id = auth.uid()
    )
  );

CREATE POLICY "Companies can create assignments in their schedules"
  ON schedule_assignments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM work_schedules
      WHERE work_schedules.id = schedule_id
      AND work_schedules.company_id = auth.uid()
    )
  );

CREATE POLICY "Companies can update assignments in their schedules"
  ON schedule_assignments
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM work_schedules
      WHERE work_schedules.id = schedule_id
      AND work_schedules.company_id = auth.uid()
    )
  );

CREATE POLICY "Companies can delete assignments in their schedules"
  ON schedule_assignments
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM work_schedules
      WHERE work_schedules.id = schedule_id
      AND work_schedules.company_id = auth.uid()
    )
  );

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS work_schedules_company_id_idx ON work_schedules(company_id);
CREATE INDEX IF NOT EXISTS schedule_shifts_schedule_id_idx ON schedule_shifts(schedule_id);
CREATE INDEX IF NOT EXISTS schedule_assignments_schedule_id_idx ON schedule_assignments(schedule_id);
CREATE INDEX IF NOT EXISTS schedule_assignments_employee_id_idx ON schedule_assignments(employee_id);