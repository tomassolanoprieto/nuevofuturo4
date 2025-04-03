-- Remove foreign key constraints from all tables
ALTER TABLE employee_profiles
DROP CONSTRAINT IF EXISTS employee_profiles_company_id_fkey;

ALTER TABLE supervisor_profiles 
DROP CONSTRAINT IF EXISTS supervisor_profiles_company_id_fkey;

ALTER TABLE time_entries
DROP CONSTRAINT IF EXISTS time_entries_employee_id_fkey;

ALTER TABLE time_requests
DROP CONSTRAINT IF EXISTS time_requests_employee_id_fkey;

ALTER TABLE planner_requests
DROP CONSTRAINT IF EXISTS planner_requests_employee_id_fkey;

ALTER TABLE calendar_events
DROP CONSTRAINT IF EXISTS calendar_events_employee_id_fkey;

ALTER TABLE daily_work_hours
DROP CONSTRAINT IF EXISTS daily_work_hours_employee_id_fkey;

-- Create indexes instead for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_company_id 
ON employee_profiles(company_id);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_company_id 
ON supervisor_profiles(company_id);

CREATE INDEX IF NOT EXISTS idx_time_entries_employee_id 
ON time_entries(employee_id);

CREATE INDEX IF NOT EXISTS idx_time_requests_employee_id 
ON time_requests(employee_id);

CREATE INDEX IF NOT EXISTS idx_planner_requests_employee_id 
ON planner_requests(employee_id);

CREATE INDEX IF NOT EXISTS idx_calendar_events_employee_id 
ON calendar_events(employee_id);

CREATE INDEX IF NOT EXISTS idx_daily_work_hours_employee_id 
ON daily_work_hours(employee_id);