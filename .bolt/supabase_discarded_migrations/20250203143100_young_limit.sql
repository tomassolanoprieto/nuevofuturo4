-- Create table for daily work hours if it doesn't exist
CREATE TABLE IF NOT EXISTS daily_work_hours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES employee_profiles(id),
  work_date DATE NOT NULL,
  fiscal_name TEXT NOT NULL,
  assigned_centers work_center_enum[],
  delegation delegation_enum,
  entry_types TEXT[] NOT NULL,
  timestamps TIMESTAMPTZ[] NOT NULL,
  work_centers work_center_enum[],
  time_types TEXT[],
  total_hours NUMERIC NOT NULL DEFAULT 0,
  hours_by_type JSONB DEFAULT '{}'::jsonb,
  hours_by_center JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(employee_id, work_date)
);

-- Enable RLS
ALTER TABLE daily_work_hours ENABLE ROW LEVEL SECURITY;

-- Create function to calculate work hours
CREATE OR REPLACE FUNCTION calculate_work_hours(
  p_employee_id UUID,
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ,
  OUT total_hours NUMERIC,
  OUT hours_by_type JSONB,
  OUT hours_by_center JSONB
) AS $$
DECLARE
  v_clock_in TIMESTAMPTZ;
  v_break_start TIMESTAMPTZ;
  v_current_type TEXT;
  v_current_center TEXT;
  v_type_minutes JSONB := '{}'::JSONB;
  v_center_minutes JSONB := '{}'::JSONB;
  r_entry RECORD;
BEGIN
  -- Initialize output variables
  total_hours := 0;
  hours_by_type := '{}'::JSONB;
  hours_by_center := '{}'::JSONB;

  FOR r_entry IN (
    SELECT *
    FROM time_entries
    WHERE employee_id = p_employee_id
    AND timestamp BETWEEN p_start_date AND p_end_date
    ORDER BY timestamp ASC
  ) LOOP
    CASE r_entry.entry_type
      WHEN 'clock_in' THEN
        v_clock_in := r_entry.timestamp;
        v_current_type := COALESCE(r_entry.time_type, 'sin_tipo');
        v_current_center := COALESCE(r_entry.work_center::TEXT, 'sin_centro');
      WHEN 'break_start' THEN
        IF v_clock_in IS NOT NULL THEN
          -- Add time to totals
          v_type_minutes := jsonb_set(
            v_type_minutes,
            ARRAY[v_current_type],
            to_jsonb(COALESCE((v_type_minutes->>v_current_type)::numeric, 0) + 
              EXTRACT(EPOCH FROM (r_entry.timestamp - v_clock_in))/60)
          );
          v_center_minutes := jsonb_set(
            v_center_minutes,
            ARRAY[v_current_center],
            to_jsonb(COALESCE((v_center_minutes->>v_current_center)::numeric, 0) + 
              EXTRACT(EPOCH FROM (r_entry.timestamp - v_clock_in))/60)
          );
          v_clock_in := NULL;
        END IF;
        v_break_start := r_entry.timestamp;
      WHEN 'break_end' THEN
        v_break_start := NULL;
        v_clock_in := r_entry.timestamp;
        v_current_type := COALESCE(r_entry.time_type, 'sin_tipo');
        v_current_center := COALESCE(r_entry.work_center::TEXT, 'sin_centro');
      WHEN 'clock_out' THEN
        IF v_clock_in IS NOT NULL THEN
          -- Add time to totals
          v_type_minutes := jsonb_set(
            v_type_minutes,
            ARRAY[v_current_type],
            to_jsonb(COALESCE((v_type_minutes->>v_current_type)::numeric, 0) + 
              EXTRACT(EPOCH FROM (r_entry.timestamp - v_clock_in))/60)
          );
          v_center_minutes := jsonb_set(
            v_center_minutes,
            ARRAY[v_current_center],
            to_jsonb(COALESCE((v_center_minutes->>v_current_center)::numeric, 0) + 
              EXTRACT(EPOCH FROM (r_entry.timestamp - v_clock_in))/60)
          );
          v_clock_in := NULL;
        END IF;
    END CASE;
  END LOOP;

  -- Convert minutes to hours
  SELECT jsonb_object_agg(key, value::numeric / 60)
  INTO hours_by_type
  FROM jsonb_each(v_type_minutes);

  SELECT jsonb_object_agg(key, value::numeric / 60)
  INTO hours_by_center
  FROM jsonb_each(v_center_minutes);

  -- Calculate total hours
  total_hours := (
    SELECT SUM(value::numeric) / 60
    FROM jsonb_each_text(v_type_minutes)
  );

  -- Handle null case
  total_hours := COALESCE(total_hours, 0);
END;
$$ LANGUAGE plpgsql;

-- Create function to update daily work hours
CREATE OR REPLACE FUNCTION update_daily_work_hours()
RETURNS TRIGGER AS $$
DECLARE
  v_date DATE;
  v_employee_id UUID;
  v_employee RECORD;
  v_hours RECORD;
BEGIN
  -- Get the date and employee_id from the time entry
  v_date := date_trunc('day', COALESCE(NEW.timestamp, OLD.timestamp))::DATE;
  v_employee_id := COALESCE(NEW.employee_id, OLD.employee_id);

  -- Get employee details
  SELECT * INTO v_employee
  FROM employee_profiles
  WHERE id = v_employee_id;

  -- Calculate hours for the day
  SELECT * INTO v_hours FROM calculate_work_hours(
    v_employee_id,
    v_date::timestamptz,
    (v_date + interval '1 day')::timestamptz
  );

  -- Insert or update daily work hours
  INSERT INTO daily_work_hours (
    employee_id,
    work_date,
    fiscal_name,
    assigned_centers,
    delegation,
    entry_types,
    timestamps,
    work_centers,
    time_types,
    total_hours,
    hours_by_type,
    hours_by_center
  )
  SELECT 
    v_employee_id,
    v_date,
    v_employee.fiscal_name,
    v_employee.work_centers,
    v_employee.delegation,
    array_agg(entry_type ORDER BY timestamp),
    array_agg(timestamp ORDER BY timestamp),
    array_agg(work_center ORDER BY timestamp),
    array_agg(time_type ORDER BY timestamp),
    v_hours.total_hours,
    v_hours.hours_by_type,
    v_hours.hours_by_center
  FROM time_entries
  WHERE employee_id = v_employee_id
  AND date_trunc('day', timestamp)::DATE = v_date
  GROUP BY employee_id
  ON CONFLICT (employee_id, work_date) DO UPDATE
  SET
    fiscal_name = EXCLUDED.fiscal_name,
    assigned_centers = EXCLUDED.assigned_centers,
    delegation = EXCLUDED.delegation,
    entry_types = EXCLUDED.entry_types,
    timestamps = EXCLUDED.timestamps,
    work_centers = EXCLUDED.work_centers,
    time_types = EXCLUDED.time_types,
    total_hours = EXCLUDED.total_hours,
    hours_by_type = EXCLUDED.hours_by_type,
    hours_by_center = EXCLUDED.hours_by_center,
    updated_at = now();

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update daily work hours
CREATE TRIGGER update_daily_work_hours_trigger
  AFTER INSERT OR UPDATE OR DELETE ON time_entries
  FOR EACH ROW
  EXECUTE FUNCTION update_daily_work_hours();

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_daily_work_hours_employee_date 
ON daily_work_hours(employee_id, work_date);

CREATE INDEX IF NOT EXISTS idx_daily_work_hours_hours_by_type 
ON daily_work_hours USING gin(hours_by_type);

CREATE INDEX IF NOT EXISTS idx_daily_work_hours_hours_by_center 
ON daily_work_hours USING gin(hours_by_center);

-- Create policy for access control
CREATE POLICY "Users can view daily work hours"
  ON daily_work_hours
  FOR SELECT
  TO authenticated
  USING (
    employee_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = daily_work_hours.employee_id
      AND ep.company_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      JOIN employee_profiles ep ON ep.id = daily_work_hours.employee_id
      WHERE sp.id = auth.uid()
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  );