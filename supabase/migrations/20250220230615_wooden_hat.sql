-- Create function to handle time request approval
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
      CASE 
        WHEN NEW.entry_type = 'clock_in' THEN 'turno'
        ELSE NULL
      END,
      CASE 
        WHEN NEW.entry_type = 'clock_in' THEN (
          SELECT work_centers[1]
          FROM employee_profiles
          WHERE id = NEW.employee_id
          AND array_length(work_centers, 1) = 1
        )
        ELSE NULL
      END
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for time request approval
CREATE TRIGGER handle_time_request_approval_trigger
  AFTER UPDATE OF status ON time_requests
  FOR EACH ROW
  EXECUTE FUNCTION handle_time_request_approval();

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_time_requests_status 
ON time_requests(status);