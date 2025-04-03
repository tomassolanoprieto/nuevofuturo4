-- Add time_type column to time_entries table
ALTER TABLE time_entries
ADD COLUMN IF NOT EXISTS time_type TEXT CHECK (
  time_type IN ('turno', 'coordinacion', 'formacion', 'sustitucion', 'otros')
);

-- Create index for time_type
CREATE INDEX IF NOT EXISTS time_entries_time_type_idx ON time_entries(time_type);