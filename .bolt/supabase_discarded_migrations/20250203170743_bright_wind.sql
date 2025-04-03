-- Drop existing objects
DROP VIEW IF EXISTS daily_work_hours;
DROP TABLE IF EXISTS daily_work_hours;
DROP FUNCTION IF EXISTS calculate_work_hours CASCADE;
DROP FUNCTION IF EXISTS calculate_daily_hours CASCADE;
DROP FUNCTION IF EXISTS update_daily_hours CASCADE;

-- Create simplified work hours table
CREATE TABLE work_hours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES employee_profiles(id),
  date DATE NOT NULL,
  type TEXT NOT NULL,
  work_center work_center_enum,
  hours NUMERIC NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(employee_id, date, type, work_center)
);

-- Enable RLS
ALTER TABLE work_hours ENABLE ROW LEVEL SECURITY;

-- Create function to update work hours
CREATE OR REPLACE FUNCTION update_work_hours()
RETURNS TRIGGER AS $$
DECLARE
  v_date DATE;
  v_employee_id UUID;
  v_hours NUMERIC;
  v_last_clock_in TIMESTAMPTZ;
  r_entry RECORD;
BEGIN
  -- Get the date and employee_id
  v_date := date_trunc('day', COALESCE(NEW.timestamp, OLD.timestamp))::DATE;
  v_employee_id := COALESCE(NEW.employee_id, OLD.employee_id);

  -- Delete existing hours for this employee and date
  DELETE FROM work_hours
  WHERE employee_id = v_employee_id
  AND date = v_date;

  -- Calculate hours for each type and work center
  FOR r_entry IN (
    SELECT 
      time_type,
      work_center,
      timestamp,
      entry_type,
      lead(timestamp) OVER (ORDER BY timestamp) as next_timestamp,
      lead(entry_type) OVER (ORDER BY timestamp) as next_entry_type
    FROM time_entries
    WHERE employee_id = v_employee_id
    AND date_trunc('day', timestamp)::DATE = v_date
    ORDER BY timestamp
  ) LOOP
    -- Only process clock_in entries
    IF r_entry.entry_type = 'clock_in' THEN
      -- Calculate hours until next non-break entry
      SELECT 
        EXTRACT(EPOCH FROM (
          CASE 
            WHEN r_entry.next_entry_type = 'break_start' THEN r_entry.next_timestamp
            WHEN r_entry.next_entry_type = 'clock_out' THEN r_entry.next_timestamp
            ELSE now()
          END
          - r_entry.timestamp
        ))/3600 INTO v_hours;

      -- Insert hours record
      INSERT INTO work_hours (
        employee_id,
        date,
        type,
        work_center,
        hours
      )
      VALUES (
        v_employee_id,
        v_date,
        COALESCE(r_entry.time_type, 'sin_tipo'),
        r_entry.work_center,
        v_hours
      )
      ON CONFLICT (employee_id, date, type, work_center)
      DO UPDATE SET
        hours = work_hours.hours + v_hours,
        updated_at = now();
    END IF;
  END LOOP;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER update_work_hours_trigger
  AFTER INSERT OR UPDATE OR DELETE ON time_entries
  FOR EACH ROW
  EXECUTE FUNCTION update_work_hours();

-- Create policy for access control
CREATE POLICY "Users can view work hours"
  ON work_hours
  FOR SELECT
  TO authenticated
  USING (
    employee_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = work_hours.employee_id
      AND ep.company_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      JOIN employee_profiles ep ON ep.id = work_hours.employee_id
      WHERE sp.id = auth.uid()
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  );

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_work_hours_employee_date 
ON work_hours(employee_id, date);

CREATE INDEX IF NOT EXISTS idx_work_hours_type 
ON work_hours(type);

CREATE INDEX IF NOT EXISTS idx_work_hours_work_center 
ON work_hours(work_center);