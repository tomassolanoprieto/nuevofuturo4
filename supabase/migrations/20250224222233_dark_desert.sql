-- Drop triggers first
DO $$ 
BEGIN
    -- Drop any triggers created by create_time_entry_audit_trigger
    DROP TRIGGER IF EXISTS time_entry_audit_fichaje_erroneo ON time_entries CASCADE;
    DROP TRIGGER IF EXISTS time_entry_audit_fuera_de_horario ON time_entries CASCADE;
    DROP TRIGGER IF EXISTS time_entry_audit_otro ON time_entries CASCADE;
    DROP TRIGGER IF EXISTS time_entry_change_trigger ON time_entries CASCADE;
EXCEPTION
    WHEN undefined_object THEN null;
END $$;

-- Drop functions with CASCADE to handle dependencies
DROP FUNCTION IF EXISTS record_time_entry_change() CASCADE;
DROP FUNCTION IF EXISTS update_time_entry_with_reason(UUID, TEXT, TIMESTAMPTZ, time_entry_change_reason, TEXT) CASCADE;
DROP FUNCTION IF EXISTS delete_time_entry_with_reason(UUID, time_entry_change_reason, TEXT) CASCADE;
DROP FUNCTION IF EXISTS create_time_entry_audit_trigger(time_entry_change_reason, TEXT) CASCADE;

-- Drop table and related types with CASCADE
DROP TABLE IF EXISTS time_entry_changes CASCADE;
DROP TYPE IF EXISTS time_entry_change_type CASCADE;
DROP TYPE IF EXISTS time_entry_change_reason CASCADE;

-- Create simple policy for time entries
CREATE POLICY "time_entries_access_v10"
  ON time_entries
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);