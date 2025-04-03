-- Add work_center and delegation columns to holidays table
ALTER TABLE holidays
ADD COLUMN IF NOT EXISTS work_center work_center_enum,
ADD COLUMN IF NOT EXISTS delegation delegation_enum;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_holidays_work_center 
ON holidays(work_center);

CREATE INDEX IF NOT EXISTS idx_holidays_delegation 
ON holidays(delegation);

-- Update existing holidays to set delegation based on work center
UPDATE holidays h
SET delegation = (
  CASE 
    WHEN h.work_center LIKE 'MADRID%' THEN 'MADRID'
    WHEN h.work_center LIKE 'ALAVA%' THEN 'ALAVA'
    WHEN h.work_center LIKE 'SANTANDER%' THEN 'SANTANDER'
    WHEN h.work_center LIKE 'SEVILLA%' THEN 'SEVILLA'
    WHEN h.work_center LIKE 'VALLADOLID%' THEN 'VALLADOLID'
    WHEN h.work_center LIKE 'MURCIA%' THEN 'MURCIA'
    WHEN h.work_center LIKE 'BURGOS%' THEN 'BURGOS'
    WHEN h.work_center LIKE 'ALICANTE%' THEN 'ALICANTE'
    WHEN h.work_center LIKE 'CONCEPCION_LA%' THEN 'CONCEPCION_LA'
    WHEN h.work_center LIKE 'CADIZ%' THEN 'CADIZ'
    WHEN h.work_center LIKE 'PALENCIA%' THEN 'PALENCIA'
    WHEN h.work_center LIKE 'CORDOBA%' THEN 'CORDOBA'
    ELSE NULL
  END
)::delegation_enum
WHERE delegation IS NULL;

-- Create policy for holidays access
CREATE POLICY "holidays_delegation_access"
  ON holidays
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);