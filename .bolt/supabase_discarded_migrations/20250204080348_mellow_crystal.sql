-- Create holidays table
CREATE TABLE IF NOT EXISTS holidays (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  date DATE NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('national', 'regional', 'company')),
  company_id UUID REFERENCES company_profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS on holidays
ALTER TABLE holidays ENABLE ROW LEVEL SECURITY;

-- Create policies for holidays
CREATE POLICY "Users can view holidays"
  ON holidays
  FOR SELECT
  TO authenticated
  USING (
    company_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = auth.uid()
      AND ep.company_id = holidays.company_id
    ) OR
    type IN ('national', 'regional')
  );

-- Create calendar_events table
CREATE TABLE IF NOT EXISTS calendar_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES employee_profiles(id),
  event_type TEXT NOT NULL CHECK (event_type IN ('work_schedule', 'holiday', 'vacation', 'absence')),
  title TEXT NOT NULL,
  start_datetime TIMESTAMPTZ NOT NULL,
  end_datetime TIMESTAMPTZ NOT NULL,
  schedule_details JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT valid_datetime_range CHECK (end_datetime >= start_datetime)
);

-- Enable RLS on calendar_events
ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;

-- Create policies for calendar_events
CREATE POLICY "Users can view calendar events"
  ON calendar_events
  FOR SELECT
  TO authenticated
  USING (
    employee_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = calendar_events.employee_id
      AND ep.company_id = auth.uid()
    )
  );

-- Enable replica identity
ALTER TABLE holidays REPLICA IDENTITY FULL;
ALTER TABLE calendar_events REPLICA IDENTITY FULL;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_holidays_company_date ON holidays(company_id, date);
CREATE INDEX IF NOT EXISTS idx_calendar_events_employee_dates ON calendar_events(employee_id, start_datetime, end_datetime);
CREATE INDEX IF NOT EXISTS idx_calendar_events_type ON calendar_events(event_type);