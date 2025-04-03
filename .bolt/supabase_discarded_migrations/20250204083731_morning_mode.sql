-- Create materialized view for daily work hours
CREATE MATERIALIZED VIEW IF NOT EXISTS daily_work_hours AS
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
    array_agg(t.time_type ORDER BY t.timestamp) AS time_types
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
  COALESCE(
    (
      SELECT SUM(
        CASE 
          WHEN t2.entry_type = 'clock_in' AND lead(t2.entry_type) OVER (ORDER BY t2.timestamp) IN ('break_start', 'clock_out') THEN
            EXTRACT(EPOCH FROM (lead(t2.timestamp) OVER (ORDER BY t2.timestamp) - t2.timestamp))/3600
          WHEN t2.entry_type = 'break_end' AND lead(t2.entry_type) OVER (ORDER BY t2.timestamp) IN ('break_start', 'clock_out') THEN
            EXTRACT(EPOCH FROM (lead(t2.timestamp) OVER (ORDER BY t2.timestamp) - t2.timestamp))/3600
          ELSE 0
        END
      )
      FROM time_entries t2
      WHERE t2.employee_id = de.employee_id
      AND date_trunc('day', t2.timestamp) = de.work_date
    ),
    0
  ) as total_hours,
  jsonb_object_agg(
    COALESCE(t3.time_type, 'sin_tipo'),
    COUNT(*) FILTER (WHERE t3.entry_type = 'clock_in')
  ) as hours_by_type,
  jsonb_object_agg(
    COALESCE(t3.work_center::text, 'sin_centro'),
    COUNT(*) FILTER (WHERE t3.entry_type = 'clock_in')
  ) as hours_by_center
FROM day_entries de
LEFT JOIN time_entries t3 ON t3.employee_id = de.employee_id 
  AND date_trunc('day', t3.timestamp) = de.work_date
GROUP BY 
  de.employee_id,
  de.work_date,
  de.fiscal_name,
  de.assigned_centers,
  de.delegation,
  de.entry_types,
  de.timestamps,
  de.work_centers,
  de.time_types;

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

-- Create indexes for better performance
CREATE UNIQUE INDEX IF NOT EXISTS idx_daily_work_hours_employee_date 
ON daily_work_hours(employee_id, work_date);

CREATE INDEX IF NOT EXISTS idx_daily_work_hours_date 
ON daily_work_hours(work_date);

CREATE INDEX IF NOT EXISTS idx_daily_work_hours_delegation 
ON daily_work_hours(delegation);

-- Create policy for access control
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

-- Grant access to authenticated users
GRANT SELECT ON daily_work_hours TO authenticated;

-- Enable realtime for time_entries if not already enabled
ALTER TABLE time_entries REPLICA IDENTITY FULL;