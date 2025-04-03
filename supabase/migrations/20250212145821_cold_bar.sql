-- Add work_center column to holidays table if it doesn't exist
ALTER TABLE holidays
ADD COLUMN IF NOT EXISTS work_center work_center_enum;

-- Create index for work_center
CREATE INDEX IF NOT EXISTS idx_holidays_work_center 
ON holidays(work_center);

-- Create function to get holidays by work center
CREATE OR REPLACE FUNCTION get_holidays_by_work_center(
  p_work_center work_center_enum,
  p_start_date DATE,
  p_end_date DATE
)
RETURNS TABLE (
  id UUID,
  date DATE,
  name TEXT,
  type TEXT,
  work_center work_center_enum
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    h.id,
    h.date,
    h.name,
    h.type,
    h.work_center
  FROM holidays h
  WHERE (h.work_center = p_work_center OR h.work_center IS NULL)
  AND h.date BETWEEN p_start_date AND p_end_date
  ORDER BY h.date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_holidays_by_work_center TO authenticated;