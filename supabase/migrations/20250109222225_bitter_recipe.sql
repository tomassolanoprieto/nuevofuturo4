/*
  # Add PIN column to employee profiles

  1. Changes
    - Add PIN column to employee_profiles table
    - Add PIN validation check constraint
  
  2. Security
    - No changes to existing RLS policies needed
*/

ALTER TABLE employee_profiles
ADD COLUMN IF NOT EXISTS pin TEXT;

-- Add check constraint to ensure PIN is exactly 4 digits
ALTER TABLE employee_profiles
ADD CONSTRAINT pin_format CHECK (pin ~ '^\d{4}$');