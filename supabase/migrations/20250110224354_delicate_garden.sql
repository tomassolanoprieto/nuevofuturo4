-- Add schedule_details column to calendar_events
ALTER TABLE calendar_events
ADD COLUMN IF NOT EXISTS schedule_details JSONB;

-- Add index for schedule_details
CREATE INDEX IF NOT EXISTS calendar_events_schedule_details_idx ON calendar_events USING gin(schedule_details);

-- Update existing events with empty schedule_details
UPDATE calendar_events
SET schedule_details = '{}'::jsonb
WHERE schedule_details IS NULL;