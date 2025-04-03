-- Create table for daily work hours
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
  total_hours NUMERIC NOT NULL,
  hours_by_type JSONB DEFAULT '{}'::jsonb,
  hours_by_center JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(employee_id, work_date)
);

-- Enable RLS
ALTER TABLE daily_work_hours ENABLE ROW LEVEL SECURITY;

-- Create function to update daily work hours
CREATE OR REPLACE FUNCTION update_daily_work_hours()
RETURNS TRIGGER AS $$
DECLARE
  v_date DATE;
  v_employee_id UUID;
  v_employee RECORD;
  v_total_hours NUMERIC;
  v_hours_by_type JSONB;
  v_hours_by_center JSONB;
BEGIN
  -- Get the date and employee_id from the time entry
  v_date := date_trunc('day', COALESCE(NEW.timestamp, OLD.timestamp))::DATE;
  v_employee_id := COALESCE(NEW.employee_id, OLD.employee_id);

  -- Get employee details
  SELECT * INTO v_employee
  FROM employee_profiles
  WHERE id = v_employee_id;

  -- Calculate hours
  SELECT 
    (result).total_hours,
    (result).hours_by_type,
    (result).hours_by_center
  INTO v_total_hours, v_hours_by_type, v_hours_by_center
  FROM (
    SELECT calculate_work_hours(
      v_employee_id,
      v_date::timestamptz,
      (v_date + interval '1 day')::timestamptz
    ) AS result
  ) calc;

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
    v_total_hours,
    v_hours_by_type,
    v_hours_by_center
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

-- Create policies for access control
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

-- Populate initial data
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
SELECT DISTINCT ON (t.employee_id, date_trunc('day', t.timestamp))
  t.employee_id,
  date_trunc('day', t.timestamp)::DATE as work_date,
  ep.fiscal_name,
  ep.work_centers as assigned_centers,
  ep.delegation,
  array_agg(t.entry_type ORDER BY t.timestamp) as entry_types,
  array_agg(t.timestamp ORDER BY t.timestamp) as timestamps,
  array_agg(t.work_center ORDER BY t.timestamp) as work_centers,
  array_agg(t.time_type ORDER BY t.timestamp) as time_types,
  (calculate_work_hours(
    t.employee_id,
    date_trunc('day', t.timestamp),
    date_trunc('day', t.timestamp) + interval '1 day'
  )).total_hours as total_hours,
  (calculate_work_hours(
    t.employee_id,
    date_trunc('day', t.timestamp),
    date_trunc('day', t.timestamp) + interval '1 day'
  )).hours_by_type as hours_by_type,
  (calculate_work_hours(
    t.employee_id,
    date_trunc('day', t.timestamp),
    date_trunc('day', t.timestamp) + interval '1 day'
  )).hours_by_center as hours_by_center
FROM time_entries t
JOIN employee_profiles ep ON ep.id = t.employee_id
GROUP BY 
  t.employee_id,
  date_trunc('day', t.timestamp),
  ep.fiscal_name,
  ep.work_centers,
  ep.delegation
ON CONFLICT (employee_id, work_date) DO NOTHING;