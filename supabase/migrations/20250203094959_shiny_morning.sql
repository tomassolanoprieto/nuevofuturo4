-- Drop absence_requests table
DROP TABLE IF EXISTS absence_requests;

-- Rename vacation_requests to planner_requests
ALTER TABLE vacation_requests RENAME TO planner_requests;

-- Add type column to planner_requests
ALTER TABLE planner_requests 
ADD COLUMN planner_type TEXT CHECK (
  planner_type IN (
    'Horas compensadas',
    'Horas vacaciones',
    'Horas asuntos propios'
  )
);

-- Update existing records to have a default planner_type
UPDATE planner_requests
SET planner_type = 'Horas vacaciones'
WHERE planner_type IS NULL;

-- Make planner_type required
ALTER TABLE planner_requests
ALTER COLUMN planner_type SET NOT NULL;

-- Rename policies for clarity
ALTER POLICY "Users can view vacation requests" ON planner_requests
RENAME TO "Users can view planner requests";

ALTER POLICY "Users can update vacation requests" ON planner_requests
RENAME TO "Users can update planner requests";

-- Enable realtime for planner_requests if not already enabled
ALTER TABLE planner_requests REPLICA IDENTITY FULL;