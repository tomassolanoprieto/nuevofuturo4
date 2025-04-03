-- Add function to calculate total work hours for a time period
CREATE OR REPLACE FUNCTION calculate_work_hours(
  p_employee_id UUID,
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ
) RETURNS NUMERIC AS $$
DECLARE
  v_total_minutes NUMERIC := 0;
  v_clock_in TIMESTAMPTZ;
  v_break_start TIMESTAMPTZ;
  r_entry RECORD;
BEGIN
  -- Get all time entries for the period, ordered by timestamp
  FOR r_entry IN (
    SELECT *
    FROM time_entries
    WHERE employee_id = p_employee_id
    AND timestamp BETWEEN p_start_date AND p_end_date
    ORDER BY timestamp ASC
  )
  LOOP
    CASE r_entry.entry_type
      WHEN 'clock_in' THEN
        v_clock_in := r_entry.timestamp;
      WHEN 'break_start' THEN
        IF v_clock_in IS NOT NULL THEN
          v_total_minutes := v_total_minutes + 
            EXTRACT(EPOCH FROM (r_entry.timestamp - v_clock_in))/60;
          v_clock_in := NULL;
        END IF;
        v_break_start := r_entry.timestamp;
      WHEN 'break_end' THEN
        v_break_start := NULL;
        v_clock_in := r_entry.timestamp;
      WHEN 'clock_out' THEN
        IF v_clock_in IS NOT NULL THEN
          v_total_minutes := v_total_minutes + 
            EXTRACT(EPOCH FROM (r_entry.timestamp - v_clock_in))/60;
          v_clock_in := NULL;
        END IF;
    END CASE;
  END LOOP;

  -- If still clocked in at end of period, count until end_date
  IF v_clock_in IS NOT NULL AND v_break_start IS NULL THEN
    v_total_minutes := v_total_minutes + 
      EXTRACT(EPOCH FROM (p_end_date - v_clock_in))/60;
  END IF;

  -- Convert minutes to hours
  RETURN v_total_minutes / 60;
END;
$$ LANGUAGE plpgsql;

-- Create materialized view for daily work hours
CREATE MATERIALIZED VIEW daily_work_hours AS
WITH day_entries AS (
  SELECT 
    employee_id,
    date_trunc('day', timestamp) AS work_date,
    array_agg(entry_type ORDER BY timestamp) AS entry_types,
    array_agg(timestamp ORDER BY timestamp) AS timestamps,
    array_agg(work_center ORDER BY timestamp) AS work_centers,
    array_agg(time_type ORDER BY timestamp) AS time_types
  FROM time_entries
  GROUP BY employee_id, date_trunc('day', timestamp)
)
SELECT 
  de.employee_id,
  de.work_date,
  ep.fiscal_name,
  ep.work_centers AS assigned_centers,
  ep.delegation,
  de.entry_types,
  de.timestamps,
  de.work_centers,
  de.time_types,
  calculate_work_hours(
    de.employee_id, 
    de.work_date, 
    de.work_date + interval '1 day'
  ) AS total_hours
FROM day_entries de
JOIN employee_profiles ep ON ep.id = de.employee_id;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_time_entries_employee_timestamp 
ON time_entries(employee_id, timestamp);

CREATE INDEX IF NOT EXISTS idx_time_entries_type_timestamp 
ON time_entries(entry_type, timestamp);

-- Create function to refresh materialized view
CREATE OR REPLACE FUNCTION refresh_daily_work_hours()
RETURNS TRIGGER AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY daily_work_hours;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to refresh materialized view
CREATE TRIGGER refresh_daily_work_hours_trigger
  AFTER INSERT OR UPDATE OR DELETE ON time_entries
  FOR EACH STATEMENT
  EXECUTE FUNCTION refresh_daily_work_hours();

-- Grant access to authenticated users
GRANT SELECT ON daily_work_hours TO authenticated;