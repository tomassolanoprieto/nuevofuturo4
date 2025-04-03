-- Drop existing policies if they exist
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Companies can view their calendars" ON work_calendars;
    DROP POLICY IF EXISTS "Companies can create calendars" ON work_calendars;
    DROP POLICY IF EXISTS "Companies can update their calendars" ON work_calendars;
    DROP POLICY IF EXISTS "Companies can delete their calendars" ON work_calendars;
    DROP POLICY IF EXISTS "Companies can view their holidays" ON holidays;
    DROP POLICY IF EXISTS "Companies can create holidays" ON holidays;
    DROP POLICY IF EXISTS "Companies can update their holidays" ON holidays;
    DROP POLICY IF EXISTS "Companies can delete their holidays" ON holidays;
EXCEPTION
    WHEN undefined_object THEN null;
END $$;

-- Add company_id to holidays if it doesn't exist
ALTER TABLE holidays 
ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES company_profiles(id) ON DELETE CASCADE;

-- Create or update policies for work_calendars
CREATE POLICY "Companies can view their calendars"
  ON work_calendars
  FOR SELECT
  TO authenticated
  USING (company_id = auth.uid());

CREATE POLICY "Companies can create calendars"
  ON work_calendars
  FOR INSERT
  TO authenticated
  WITH CHECK (company_id = auth.uid());

CREATE POLICY "Companies can update their calendars"
  ON work_calendars
  FOR UPDATE
  TO authenticated
  USING (company_id = auth.uid());

CREATE POLICY "Companies can delete their calendars"
  ON work_calendars
  FOR DELETE
  TO authenticated
  USING (company_id = auth.uid());

-- Create or update policies for holidays
CREATE POLICY "Companies can view their holidays"
  ON holidays
  FOR SELECT
  TO authenticated
  USING (company_id = auth.uid() OR type IN ('national', 'regional'));

CREATE POLICY "Companies can create holidays"
  ON holidays
  FOR INSERT
  TO authenticated
  WITH CHECK (
    company_id = auth.uid() AND
    type = 'company'
  );

CREATE POLICY "Companies can update their holidays"
  ON holidays
  FOR UPDATE
  TO authenticated
  USING (
    company_id = auth.uid() AND
    type = 'company'
  );

CREATE POLICY "Companies can delete their holidays"
  ON holidays
  FOR DELETE
  TO authenticated
  USING (
    company_id = auth.uid() AND
    type = 'company'
  );

-- Add or update indexes
DROP INDEX IF EXISTS holidays_calendar_id_idx;
CREATE INDEX IF NOT EXISTS holidays_date_idx ON holidays(date);
CREATE INDEX IF NOT EXISTS holidays_company_id_idx ON holidays(company_id);