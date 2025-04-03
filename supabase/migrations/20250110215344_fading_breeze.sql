/*
  # Work Calendar Schema

  1. New Tables
    - `work_calendars`: Stores company work calendars
      - `id` (uuid, primary key)
      - `name` (text)
      - `year` (integer)
      - `description` (text)
      - `company_id` (uuid, references company_profiles)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

    - `holidays`: Stores holidays for each calendar
      - `id` (uuid, primary key)
      - `calendar_id` (uuid, references work_calendars)
      - `date` (date)
      - `name` (text)
      - `type` (text: national, regional, company)
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on both tables
    - Add policies for company access
*/

-- Create work_calendars table
CREATE TABLE IF NOT EXISTS work_calendars (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  year INTEGER NOT NULL,
  description TEXT,
  company_id UUID REFERENCES company_profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT valid_year CHECK (year >= 1900 AND year <= 2100)
);

-- Create holidays table
CREATE TABLE IF NOT EXISTS holidays (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  calendar_id UUID REFERENCES work_calendars(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('national', 'regional', 'company')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE work_calendars ENABLE ROW LEVEL SECURITY;
ALTER TABLE holidays ENABLE ROW LEVEL SECURITY;

-- Policies for work_calendars
CREATE POLICY "Companies can view their calendars"
  ON work_calendars
  FOR SELECT
  TO authenticated
  USING (company_id = auth.uid());

CREATE POLICY "Companies can create calendars"
  ON work_calendars
  FOR INSERT
  TO authenticated
  WITH CHECK (company_id = auth.uid());

CREATE POLICY "Companies can update their calendars"
  ON work_calendars
  FOR UPDATE
  TO authenticated
  USING (company_id = auth.uid());

CREATE POLICY "Companies can delete their calendars"
  ON work_calendars
  FOR DELETE
  TO authenticated
  USING (company_id = auth.uid());

-- Policies for holidays
CREATE POLICY "Companies can view holidays in their calendars"
  ON holidays
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM work_calendars
      WHERE work_calendars.id = calendar_id
      AND work_calendars.company_id = auth.uid()
    )
  );

CREATE POLICY "Companies can create holidays in their calendars"
  ON holidays
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM work_calendars
      WHERE work_calendars.id = calendar_id
      AND work_calendars.company_id = auth.uid()
    )
  );

CREATE POLICY "Companies can update holidays in their calendars"
  ON holidays
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM work_calendars
      WHERE work_calendars.id = calendar_id
      AND work_calendars.company_id = auth.uid()
    )
  );

CREATE POLICY "Companies can delete holidays in their calendars"
  ON holidays
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM work_calendars
      WHERE work_calendars.id = calendar_id
      AND work_calendars.company_id = auth.uid()
    )
  );

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS work_calendars_company_id_idx ON work_calendars(company_id);
CREATE INDEX IF NOT EXISTS holidays_calendar_id_idx ON holidays(calendar_id);
CREATE INDEX IF NOT EXISTS holidays_date_idx ON holidays(date);