/*
  # Update employee profiles table

  1. Changes
    - Add new columns for employee management
*/

-- Add new columns if they don't exist
ALTER TABLE employee_profiles
ADD COLUMN IF NOT EXISTS employee_id TEXT,
ADD COLUMN IF NOT EXISTS document_type TEXT,
ADD COLUMN IF NOT EXISTS document_number TEXT,
ADD COLUMN IF NOT EXISTS work_center TEXT;