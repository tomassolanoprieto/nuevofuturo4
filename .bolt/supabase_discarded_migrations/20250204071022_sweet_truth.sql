-- Drop existing materialized view if exists
DROP MATERIALIZED VIEW IF EXISTS daily_work_hours;

-- Create regular view for daily work hours
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
    array_agg(t.time_type ORDER BY t.timestamp) AS time_types
  FROM time_entries t
  JOIN employee_profiles ep ON ep.id = t.employee_id
  GROUP BY 
    t.employee_id,
    date_trunc('day', t.timestamp),
    ep.fiscal_name,
    ep.work_centers,
    ep.delegation
),
calculated_hours AS (
  SELECT
    de.employee_id,
    de.work_date,
    COALESCE(
      SUM(
        CASE 
          WHEN lead(t.timestamp) OVER (ORDER BY t.timestamp) IS NOT NULL THEN
            EXTRACT(EPOCH FROM (lead(t.timestamp) OVER (ORDER BY t.timestamp) - t.timestamp))/3600
          ELSE 0
        END
      ),
      0
    ) as total_hours,
    jsonb_object_agg(
      COALESCE(t.time_type, 'sin_tipo'),
      COUNT(*) FILTER (WHERE t.entry_type = 'clock_in')
    ) as hours_by_type,
    jsonb_object_agg(
      COALESCE(t.work_center::text, 'sin_centro'),
      COUNT(*) FILTER (WHERE t.entry_type = 'clock_in')
    ) as hours_by_center
  FROM day_entries de
  LEFT JOIN time_entries t ON t.employee_id = de.employee_id 
    AND date_trunc('day', t.timestamp) = de.work_date
  GROUP BY de.employee_id, de.work_date
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
  ch.total_hours,
  ch.hours_by_type,
  ch.hours_by_center
FROM day_entries de
JOIN calculated_hours ch ON ch.employee_id = de.employee_id AND ch.work_date = de.work_date;

-- Create policy for view access
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