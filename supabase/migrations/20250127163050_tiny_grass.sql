-- Enable realtime for required tables
ALTER TABLE employee_profiles REPLICA IDENTITY FULL;
ALTER TABLE time_entries REPLICA IDENTITY FULL;
ALTER TABLE time_requests REPLICA IDENTITY FULL;
ALTER TABLE vacation_requests REPLICA IDENTITY FULL;
ALTER TABLE absence_requests REPLICA IDENTITY FULL;
ALTER TABLE calendar_events REPLICA IDENTITY FULL;

-- Enable publication for realtime if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END
$$;

-- Add tables to the publication
ALTER PUBLICATION supabase_realtime ADD TABLE 
  employee_profiles,
  time_entries,
  time_requests,
  vacation_requests,
  absence_requests,
  calendar_events;