-- Drop existing function if exists
DROP FUNCTION IF EXISTS calculate_work_hours(UUID, TIMESTAMPTZ, TIMESTAMPTZ);

-- Add function to calculate total work hours for a time period
CREATE OR REPLACE FUNCTION calculate_work_hours(
  p_employee_id UUID,
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ,
  OUT total_hours NUMERIC,
  OUT hours_by_type JSONB,
  OUT hours_by_center JSONB
) AS $$
DECLARE
  v_total_minutes NUMERIC := 0;
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
        v_current_type := COALESCE(r_entry.time_type, 'sin_tipo');
        v_current_center := COALESCE(r_entry.work_center::TEXT, 'sin_centro');
      WHEN 'break_start' THEN
        IF v_clock_in IS NOT NULL THEN
          -- Calculate minutes for this period
          v_total_minutes := v_total_minutes + 
            EXTRACT(EPOCH FROM (r_entry.timestamp - v_clock_in))/60;
          
          -- Add minutes to type totals
          v_type_minutes := jsonb_set(
            v_type_minutes,
            ARRAY[v_current_type],
            to_jsonb(COALESCE((v_type_minutes->>v_current_type)::numeric, 0) + 
              EXTRACT(EPOCH FROM (r_entry.timestamp - v_clock_in))/60)
          );
          
          -- Add minutes to center totals
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
          -- Calculate minutes for this period
          v_total_minutes := v_total_minutes + 
            EXTRACT(EPOCH FROM (r_entry.timestamp - v_clock_in))/60;
          
          -- Add minutes to type totals
          v_type_minutes := jsonb_set(
            v_type_minutes,
            ARRAY[v_current_type],
            to_jsonb(COALESCE((v_type_minutes->>v_current_type)::numeric, 0) + 
              EXTRACT(EPOCH FROM (r_entry.timestamp - v_clock_in))/60)
          );
          
          -- Add minutes to center totals
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

  -- If still clocked in at end of period, count until end_date
  IF v_clock_in IS NOT NULL AND v_break_start IS NULL THEN
    -- Calculate final minutes
    v_total_minutes := v_total_minutes + 
      EXTRACT(EPOCH FROM (p_end_date - v_clock_in))/60;
    
    -- Add final minutes to type totals
    v_type_minutes := jsonb_set(
      v_type_minutes,
      ARRAY[v_current_type],
      to_jsonb(COALESCE((v_type_minutes->>v_current_type)::numeric, 0) + 
        EXTRACT(EPOCH FROM (p_end_date - v_clock_in))/60)
    );
    
    -- Add final minutes to center totals
    v_center_minutes := jsonb_set(
      v_center_minutes,
      ARRAY[v_current_center],
      to_jsonb(COALESCE((v_center_minutes->>v_current_center)::numeric, 0) + 
        EXTRACT(EPOCH FROM (p_end_date - v_clock_in))/60)
    );
  END IF;

  -- Convert all minutes to hours
  total_hours := v_total_minutes / 60;
  
  -- Convert type minutes to hours
  SELECT jsonb_object_agg(key, value::numeric / 60)
  INTO hours_by_type
  FROM jsonb_each(v_type_minutes);
  
  -- Convert center minutes to hours
  SELECT jsonb_object_agg(key, value::numeric / 60)
  INTO hours_by_center
  FROM jsonb_each(v_center_minutes);
END;
$$ LANGUAGE plpgsql;

-- Create a view for daily work hours
CREATE OR REPLACE VIEW daily_work_hours AS
WITH day_entries AS (
  SELECT 
    t.employee_id,
    date_trunc('day', t.timestamp) AS work_date,
    ep.fiscal_name,
    ep.work_centers AS assigned_centers,
    ep.delegation,
    array_agg(t.entry_type ORDER BY t.timestamp) AS entry_types,
    array_agg(t.timestamp ORDER BY t.timestamp) AS timestamps,
    array_agg(t.work_center ORDER BY t.timestamp) AS work_centers,
    array_agg(t.time_type ORDER BY t.timestamp) AS time_types,
    calculate_work_hours(
      t.employee_id,
      date_trunc('day', t.timestamp),
      date_trunc('day', t.timestamp) + interval '1 day'
    ) AS work_hours
  FROM time_entries t
  JOIN employee_profiles ep ON ep.id = t.employee_id
  GROUP BY 
    t.employee_id,
    date_trunc('day', t.timestamp),
    ep.fiscal_name,
    ep.work_centers,
    ep.delegation
)
SELECT 
  de.employee_id,
  de.work_date,
  de.fiscal_name,
  de.assigned_centers,
  de.delegation,
  de.entry_types,
  de.timestamps,
  de.work_centers,
  de.time_types,
  (de.work_hours).total_hours,
  (de.work_hours).hours_by_type,
  (de.work_hours).hours_by_center
FROM day_entries de;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_time_entries_employee_timestamp 
ON time_entries(employee_id, timestamp);

CREATE INDEX IF NOT EXISTS idx_time_entries_type_timestamp 
ON time_entries(entry_type, timestamp);

-- Create policy for the view
CREATE POLICY "Users can view daily work hours"
  ON time_entries
  FOR SELECT
  TO authenticated
  USING (
    employee_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = time_entries.employee_id
      AND ep.company_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      JOIN employee_profiles ep ON ep.id = time_entries.employee_id
      WHERE sp.id = auth.uid()
      AND sp.company_id = ep.company_id
      AND sp.is_active = true
      AND (
        (sp.supervisor_type = 'center' AND ep.work_centers && sp.work_centers) OR
        (sp.supervisor_type = 'delegation' AND ep.delegation = ANY(sp.delegations))
      )
    )
  );