/*
  # Add is_active column to employee_profiles

  1. Changes
    - Add is_active boolean column to employee_profiles table with default value true
*/

ALTER TABLE employee_profiles
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Add document columns if they don't exist
ALTER TABLE employee_profiles
ADD COLUMN IF NOT EXISTS document_type TEXT,
ADD COLUMN IF NOT EXISTS document_number TEXT,
ADD COLUMN IF NOT EXISTS employee_id TEXT;