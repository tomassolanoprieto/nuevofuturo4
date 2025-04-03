-- Add time_type and work_center columns to time_requests
ALTER TABLE time_requests
ADD COLUMN IF NOT EXISTS time_type TEXT CHECK (
  time_type IN ('turno', 'coordinacion', 'formacion', 'sustitucion', 'otros')
),
ADD COLUMN IF NOT EXISTS work_center work_center_enum;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_time_requests_time_type 
ON time_requests(time_type);

CREATE INDEX IF NOT EXISTS idx_time_requests_work_center 
ON time_requests(work_center);

-- Update trigger function to handle time request approval
CREATE OR REPLACE FUNCTION handle_time_request_approval()
RETURNS TRIGGER AS $$
BEGIN
  -- Only proceed if status is changing to 'approved'
  IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
    -- Create time entry from request
    INSERT INTO time_entries (
      employee_id,
      entry_type,
      timestamp,
      time_type,
      work_center
    )
    VALUES (
      NEW.employee_id,
      NEW.entry_type,
      NEW.datetime,
      NEW.time_type,
      NEW.work_center
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS handle_time_request_approval_trigger ON time_requests;
CREATE TRIGGER handle_time_request_approval_trigger
  AFTER UPDATE OF status ON time_requests
  FOR EACH ROW
  EXECUTE FUNCTION handle_time_request_approval();