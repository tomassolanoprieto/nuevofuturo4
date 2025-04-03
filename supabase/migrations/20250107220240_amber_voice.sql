/*
  # Add time entries policies

  1. Changes
    - Add policy for employees to insert their own time entries
    - Add policy for employees to view their own time entries

  2. Security
    - Enable RLS policies for time entries table
    - Restrict employees to only manage their own entries
*/

-- Policy for employees to insert their own time entries
CREATE POLICY "Employees can insert their own time entries"
  ON time_entries
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = employee_id);

-- Policy for employees to view their own time entries
CREATE POLICY "Employees can view their own time entries"
  ON time_entries
  FOR SELECT
  TO authenticated
  USING (auth.uid() = employee_id);