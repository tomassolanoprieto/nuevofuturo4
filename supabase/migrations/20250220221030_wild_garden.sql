-- Create enum for change types
CREATE TYPE time_entry_change_type AS ENUM (
    'UPDATE',
    'DELETE'
);

-- Create enum for change reasons
CREATE TYPE time_entry_change_reason AS ENUM (
    'FICHAJE_ERRONEO',
    'FUERA_DE_HORARIO',
    'OTRO'
);

-- Create table for time entry changes
CREATE TABLE time_entry_changes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    time_entry_id UUID REFERENCES time_entries(id) ON DELETE CASCADE,
    change_type time_entry_change_type NOT NULL,
    change_reason time_entry_change_reason NOT NULL,
    other_reason TEXT,
    old_data JSONB,
    new_data JSONB,
    changed_by UUID REFERENCES auth.users(id),
    changed_at TIMESTAMPTZ DEFAULT now(),
    company_id UUID REFERENCES company_profiles(id)
);

-- Enable RLS
ALTER TABLE time_entry_changes ENABLE ROW LEVEL SECURITY;

-- Create policy for time entry changes
CREATE POLICY "time_entry_changes_access"
  ON time_entry_changes
  FOR ALL
  TO authenticated
  USING (
    company_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM employee_profiles ep
      WHERE ep.id = auth.uid()
      AND ep.company_id = time_entry_changes.company_id
    )
  );

-- Create function to record time entry changes
CREATE OR REPLACE FUNCTION record_time_entry_change()
RETURNS TRIGGER AS $$
DECLARE
    v_company_id UUID;
    v_old_data JSONB;
    v_new_data JSONB;
    v_change_type time_entry_change_type;
BEGIN
    -- Get company ID from employee profile
    SELECT company_id INTO v_company_id
    FROM employee_profiles
    WHERE id = COALESCE(OLD.employee_id, NEW.employee_id);

    -- Determine change type
    IF TG_OP = 'DELETE' THEN
        v_change_type := 'DELETE';
        v_old_data := to_jsonb(OLD);
        v_new_data := NULL;
    ELSE
        v_change_type := 'UPDATE';
        v_old_data := to_jsonb(OLD);
        v_new_data := to_jsonb(NEW);
    END IF;

    -- Record the change
    INSERT INTO time_entry_changes (
        time_entry_id,
        change_type,
        change_reason,
        other_reason,
        old_data,
        new_data,
        changed_by,
        company_id
    )
    VALUES (
        COALESCE(OLD.id, NEW.id),
        v_change_type,
        TG_ARGV[0]::time_entry_change_reason,
        TG_ARGV[1]::text,
        v_old_data,
        v_new_data,
        auth.uid(),
        v_company_id
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to update time entry with reason
CREATE OR REPLACE FUNCTION update_time_entry_with_reason(
    p_time_entry_id UUID,
    p_entry_type TEXT,
    p_timestamp TIMESTAMPTZ,
    p_change_reason time_entry_change_reason,
    p_other_reason TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    -- Update time entry with trigger parameters
    UPDATE time_entries
    SET 
        entry_type = p_entry_type,
        timestamp = p_timestamp
    WHERE id = p_time_entry_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to delete time entry with reason
CREATE OR REPLACE FUNCTION delete_time_entry_with_reason(
    p_time_entry_id UUID,
    p_change_reason time_entry_change_reason,
    p_other_reason TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    -- Delete time entry with trigger parameters
    DELETE FROM time_entries
    WHERE id = p_time_entry_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create dynamic trigger for updates
CREATE OR REPLACE FUNCTION create_time_entry_audit_trigger(
    p_change_reason time_entry_change_reason,
    p_other_reason TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_trigger_name TEXT;
BEGIN
    v_trigger_name := 'time_entry_audit_' || 
                      lower(p_change_reason::text) || 
                      '_' || COALESCE(md5(p_other_reason), 'null');

    EXECUTE format(
        'DROP TRIGGER IF EXISTS %I ON time_entries;
         CREATE TRIGGER %I
         AFTER UPDATE OR DELETE ON time_entries
         FOR EACH ROW
         EXECUTE FUNCTION record_time_entry_change(%L, %L);',
        v_trigger_name,
        v_trigger_name,
        p_change_reason,
        p_other_reason
    );
END;
$$ LANGUAGE plpgsql;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_time_entry_changes_time_entry_id 
ON time_entry_changes(time_entry_id);

CREATE INDEX IF NOT EXISTS idx_time_entry_changes_company_id 
ON time_entry_changes(company_id);

CREATE INDEX IF NOT EXISTS idx_time_entry_changes_changed_by 
ON time_entry_changes(changed_by);

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION update_time_entry_with_reason TO authenticated;
GRANT EXECUTE ON FUNCTION delete_time_entry_with_reason TO authenticated;