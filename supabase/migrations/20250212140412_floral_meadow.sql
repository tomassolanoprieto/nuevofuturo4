-- Create index for time_type if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_time_entries_time_type 
ON time_entries(time_type);

-- Create index for combined lookups
CREATE INDEX IF NOT EXISTS idx_time_entries_employee_type_date
ON time_entries(employee_id, time_type, get_date_from_timestamp(timestamp));

-- Update existing entries to ensure time_type consistency
WITH clock_in_entries AS (
  SELECT 
    employee_id,
    get_date_from_timestamp(timestamp) as entry_date,
    time_type,
    work_center,
    timestamp as clock_in_time
  FROM time_entries
  WHERE entry_type = 'clock_in'
)
UPDATE time_entries t
SET 
  time_type = c.time_type,
  work_center = c.work_center
FROM clock_in_entries c
WHERE t.employee_id = c.employee_id
AND get_date_from_timestamp(t.timestamp) = c.entry_date
AND t.timestamp >= c.clock_in_time
AND t.entry_type IN ('break_start', 'break_end', 'clock_out')
AND (t.time_type IS NULL OR t.work_center IS NULL);