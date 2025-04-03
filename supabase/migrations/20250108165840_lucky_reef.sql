/*
  # Add missing columns to employee_profiles table

  1. Changes
    - Add email column to store employee email
    - Add work_center column to store employee work center
*/

ALTER TABLE employee_profiles
ADD COLUMN IF NOT EXISTS email TEXT,
ADD COLUMN IF NOT EXISTS work_center TEXT;