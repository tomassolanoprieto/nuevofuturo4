-- Remove not-null constraints from auth.users
ALTER TABLE auth.users 
ALTER COLUMN instance_id DROP NOT NULL,
ALTER COLUMN aud DROP NOT NULL,
ALTER COLUMN role DROP NOT NULL,
ALTER COLUMN email_confirmed_at DROP NOT NULL,
ALTER COLUMN raw_app_meta_data DROP NOT NULL,
ALTER COLUMN raw_user_meta_data DROP NOT NULL,
ALTER COLUMN created_at DROP NOT NULL,
ALTER COLUMN updated_at DROP NOT NULL,
ALTER COLUMN confirmation_sent_at DROP NOT NULL,
ALTER COLUMN is_super_admin DROP NOT NULL,
ALTER COLUMN phone_confirmed_at DROP NOT NULL,
ALTER COLUMN confirmed_at DROP NOT NULL,
ALTER COLUMN recovery_sent_at DROP NOT NULL,
ALTER COLUMN email_change_token_current DROP NOT NULL,
ALTER COLUMN email_change_confirm_status DROP NOT NULL,
ALTER COLUMN banned_until DROP NOT NULL,
ALTER COLUMN reauthentication_sent_at DROP NOT NULL,
ALTER COLUMN is_sso_user DROP NOT NULL,
ALTER COLUMN deleted_at DROP NOT NULL;

-- Remove not-null constraints from employee_profiles
ALTER TABLE employee_profiles
ALTER COLUMN fiscal_name DROP NOT NULL,
ALTER COLUMN email DROP NOT NULL,
ALTER COLUMN country DROP NOT NULL,
ALTER COLUMN timezone DROP NOT NULL,
ALTER COLUMN pin DROP NOT NULL,
ALTER COLUMN created_at DROP NOT NULL,
ALTER COLUMN updated_at DROP NOT NULL;

-- Remove not-null constraints from time_entries
ALTER TABLE time_entries
ALTER COLUMN entry_type DROP NOT NULL,
ALTER COLUMN timestamp DROP NOT NULL,
ALTER COLUMN created_at DROP NOT NULL;

-- Remove not-null constraints from time_requests
ALTER TABLE time_requests
ALTER COLUMN datetime DROP NOT NULL,
ALTER COLUMN entry_type DROP NOT NULL,
ALTER COLUMN comment DROP NOT NULL,
ALTER COLUMN status DROP NOT NULL,
ALTER COLUMN created_at DROP NOT NULL;

-- Remove not-null constraints from planner_requests
ALTER TABLE planner_requests
ALTER COLUMN planner_type DROP NOT NULL,
ALTER COLUMN start_date DROP NOT NULL,
ALTER COLUMN end_date DROP NOT NULL,
ALTER COLUMN comment DROP NOT NULL,
ALTER COLUMN status DROP NOT NULL,
ALTER COLUMN created_at DROP NOT NULL;

-- Remove not-null constraints from calendar_events
ALTER TABLE calendar_events
ALTER COLUMN title DROP NOT NULL,
ALTER COLUMN start_datetime DROP NOT NULL,
ALTER COLUMN end_datetime DROP NOT NULL,
ALTER COLUMN event_type DROP NOT NULL,
ALTER COLUMN color DROP NOT NULL,
ALTER COLUMN created_at DROP NOT NULL,
ALTER COLUMN updated_at DROP NOT NULL;

-- Remove not-null constraints from daily_work_hours
ALTER TABLE daily_work_hours
ALTER COLUMN work_date DROP NOT NULL,
ALTER COLUMN fiscal_name DROP NOT NULL,
ALTER COLUMN entry_types DROP NOT NULL,
ALTER COLUMN timestamps DROP NOT NULL,
ALTER COLUMN total_hours DROP NOT NULL,
ALTER COLUMN created_at DROP NOT NULL,
ALTER COLUMN updated_at DROP NOT NULL;

-- Drop all check constraints
ALTER TABLE employee_profiles DROP CONSTRAINT IF EXISTS pin_format;
ALTER TABLE supervisor_profiles DROP CONSTRAINT IF EXISTS pin_format;
ALTER TABLE time_entries DROP CONSTRAINT IF EXISTS valid_entry_type;
ALTER TABLE planner_requests DROP CONSTRAINT IF EXISTS valid_date_range;
ALTER TABLE calendar_events DROP CONSTRAINT IF EXISTS valid_dates;
ALTER TABLE daily_work_hours DROP CONSTRAINT IF EXISTS valid_date_range;

-- Drop foreign key constraints
ALTER TABLE employee_profiles DROP CONSTRAINT IF EXISTS employee_profiles_company_id_fkey;
ALTER TABLE supervisor_profiles DROP CONSTRAINT IF EXISTS supervisor_profiles_company_id_fkey;
ALTER TABLE time_entries DROP CONSTRAINT IF EXISTS time_entries_employee_id_fkey;
ALTER TABLE time_requests DROP CONSTRAINT IF EXISTS time_requests_employee_id_fkey;
ALTER TABLE planner_requests DROP CONSTRAINT IF EXISTS planner_requests_employee_id_fkey;
ALTER TABLE calendar_events DROP CONSTRAINT IF EXISTS calendar_events_employee_id_fkey;
ALTER TABLE daily_work_hours DROP CONSTRAINT IF EXISTS daily_work_hours_employee_id_fkey;