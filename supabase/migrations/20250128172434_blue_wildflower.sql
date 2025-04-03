-- Add job_positions column if it doesn't exist
ALTER TABLE employee_profiles
ADD COLUMN IF NOT EXISTS job_positions job_position_enum[] DEFAULT '{}';

-- Create index for job_positions for better performance
CREATE INDEX IF NOT EXISTS employee_profiles_job_positions_idx ON employee_profiles USING GIN(job_positions);