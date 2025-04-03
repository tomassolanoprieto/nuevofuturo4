-- Create work_time_alarms table
CREATE TABLE IF NOT EXISTS work_time_alarms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES company_profiles(id),
  work_center work_center_enum,
  delegation delegation_enum,
  hours_limit INTEGER NOT NULL CHECK (hours_limit > 0),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE work_time_alarms ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Companies can manage their alarms"
  ON work_time_alarms
  FOR ALL
  TO authenticated
  USING (company_id = auth.uid())
  WITH CHECK (company_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_work_time_alarms_company ON work_time_alarms(company_id);
CREATE INDEX IF NOT EXISTS idx_work_time_alarms_work_center ON work_time_alarms(work_center);
CREATE INDEX IF NOT EXISTS idx_work_time_alarms_delegation ON work_time_alarms(delegation);