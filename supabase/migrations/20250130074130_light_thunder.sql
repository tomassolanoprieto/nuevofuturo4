-- Enable RLS for auth.users if not already enabled
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_tables 
        WHERE tablename = 'users' 
        AND schemaname = 'auth' 
        AND rowsecurity = true
    ) THEN
        ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

-- Drop existing policies if they exist
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Allow password recovery" ON auth.users;
    DROP POLICY IF EXISTS "Allow email updates" ON auth.users;
    DROP POLICY IF EXISTS "Allow password recovery for employees" ON employee_profiles;
EXCEPTION
    WHEN undefined_object THEN null;
END $$;

-- Create new policies
CREATE POLICY "Allow password recovery"
ON auth.users
FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "Allow email updates"
ON auth.users
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

CREATE POLICY "Allow password recovery for employees"
ON employee_profiles
FOR SELECT
TO anon, authenticated
USING (true);

-- Add columns to auth.users if they don't exist
DO $$ 
BEGIN
    BEGIN
        ALTER TABLE auth.users 
        ADD COLUMN email_confirmed_at TIMESTAMPTZ DEFAULT NOW();
    EXCEPTION
        WHEN duplicate_column THEN null;
    END;

    BEGIN
        ALTER TABLE auth.users 
        ADD COLUMN recovery_token TEXT;
    EXCEPTION
        WHEN duplicate_column THEN null;
    END;

    BEGIN
        ALTER TABLE auth.users 
        ADD COLUMN recovery_sent_at TIMESTAMPTZ;
    EXCEPTION
        WHEN duplicate_column THEN null;
    END;
END $$;

-- Create or replace indexes
DROP INDEX IF EXISTS idx_employee_profiles_email;
CREATE INDEX idx_employee_profiles_email 
ON employee_profiles(email);

DROP INDEX IF EXISTS idx_employee_profiles_active;
CREATE INDEX idx_employee_profiles_active 
ON employee_profiles(is_active);