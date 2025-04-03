-- Add missing fields to supervisor_profiles
ALTER TABLE supervisor_profiles
ADD COLUMN IF NOT EXISTS timezone TEXT DEFAULT 'Europe/Madrid',
ADD COLUMN IF NOT EXISTS country TEXT DEFAULT 'España',
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS employee_id TEXT;

-- Update raw_user_meta_data for existing supervisors
DO $$
DECLARE
  sup RECORD;
BEGIN
  FOR sup IN 
    SELECT * FROM supervisor_profiles 
    WHERE is_active = true
  LOOP
    BEGIN
      UPDATE auth.users 
      SET raw_user_meta_data = jsonb_build_object(
        'work_centers', sup.work_centers,
        'document_type', COALESCE(sup.document_type, 'DNI'),
        'document_number', COALESCE(sup.document_number, ''),
        'timezone', COALESCE(sup.timezone, 'Europe/Madrid'),
        'country', COALESCE(sup.country, 'España'),
        'phone', COALESCE(sup.phone, ''),
        'employee_id', COALESCE(sup.employee_id, '')
      )
      WHERE id = sup.id;
    EXCEPTION
      WHEN others THEN
        RAISE NOTICE 'Error updating supervisor %: %', sup.email, SQLERRM;
    END;
  END LOOP;
END;
$$;