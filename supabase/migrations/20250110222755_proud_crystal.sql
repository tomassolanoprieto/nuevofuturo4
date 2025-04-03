-- Create calendar_events table
CREATE TABLE IF NOT EXISTS calendar_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES employee_profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  start_datetime TIMESTAMPTZ NOT NULL,
  end_datetime TIMESTAMPTZ NOT NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('work_schedule', 'holiday', 'vacation', 'absence')),
  color TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT valid_dates CHECK (end_datetime >= start_datetime)
);

-- Enable RLS
ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;

-- Policies for calendar_events
CREATE POLICY "Companies can manage their employees' calendar events"
  ON calendar_events
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employee_profiles
      WHERE employee_profiles.id = calendar_events.employee_id
      AND employee_profiles.company_id = auth.uid()
    )
  );

-- Add indexes
CREATE INDEX IF NOT EXISTS calendar_events_employee_id_idx ON calendar_events(employee_id);
CREATE INDEX IF NOT EXISTS calendar_events_date_range_idx ON calendar_events(start_datetime, end_datetime);