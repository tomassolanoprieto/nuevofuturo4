-- Remove NOT NULL constraints from email and pin in supervisor_profiles
ALTER TABLE supervisor_profiles
ALTER COLUMN email DROP NOT NULL,
ALTER COLUMN pin DROP NOT NULL;

-- Add back the constraints without the selected/required flag
ALTER TABLE supervisor_profiles
ADD CONSTRAINT supervisor_email_not_null CHECK (email IS NOT NULL),
ADD CONSTRAINT supervisor_pin_not_null CHECK (pin IS NOT NULL);