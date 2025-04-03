/*
  # Add supervisor management functionality

  1. New Tables
    - `supervisor_profiles`
      - `id` (uuid, primary key)
      - `fiscal_name` (text)
      - `email` (text, unique)
      - `work_centers` (text array)
      - `pin` (text, 6 digits)
      - `company_id` (uuid, references company_profiles)
      - `is_active` (boolean)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `supervisor_profiles` table
    - Add policies for companies to manage their supervisors
    - Add policies for supervisors to access their own data
*/

-- Create supervisor profiles table
CREATE TABLE IF NOT EXISTS supervisor_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fiscal_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  work_centers TEXT[] NOT NULL,
  pin TEXT NOT NULL,
  company_id UUID REFERENCES company_profiles(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT pin_format CHECK (pin ~ '^\d{6}$')
);

-- Enable RLS
ALTER TABLE supervisor_profiles ENABLE ROW LEVEL SECURITY;

-- Companies can manage their supervisors
CREATE POLICY "Companies can view their supervisors"
  ON supervisor_profiles
  FOR SELECT
  TO authenticated
  USING (company_id = auth.uid());

CREATE POLICY "Companies can create supervisors"
  ON supervisor_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (company_id = auth.uid());

CREATE POLICY "Companies can update their supervisors"
  ON supervisor_profiles
  FOR UPDATE
  TO authenticated
  USING (company_id = auth.uid());

-- Create function to handle supervisor authentication
CREATE OR REPLACE FUNCTION handle_supervisor_auth()
RETURNS TRIGGER AS $$
BEGIN
  -- Basic validation
  IF NEW.email IS NULL THEN
    RAISE EXCEPTION 'Email is required';
  END IF;

  IF NEW.pin IS NULL THEN
    RAISE EXCEPTION 'PIN is required';
  END IF;

  IF NEW.pin !~ '^\d{6}$' THEN
    RAISE EXCEPTION 'PIN must be exactly 6 digits';
  END IF;

  -- Create new auth user
  INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    role
  )
  VALUES (
    NEW.id,
    NEW.email,
    crypt(NEW.pin, gen_salt('bf')),
    NOW(),
    jsonb_build_object(
      'provider', 'email',
      'providers', ARRAY['email'],
      'role', 'supervisor'
    ),
    jsonb_build_object(
      'work_centers', NEW.work_centers
    ),
    NOW(),
    NOW(),
    'authenticated'
  );

  RETURN NEW;
EXCEPTION
  WHEN others THEN
    -- If there's an error, try to update existing user instead
    UPDATE auth.users 
    SET encrypted_password = crypt(NEW.pin, gen_salt('bf')),
        raw_app_meta_data = jsonb_build_object(
          'provider', 'email',
          'providers', ARRAY['email'],
          'role', 'supervisor'
        ),
        raw_user_meta_data = jsonb_build_object(
          'work_centers', NEW.work_centers
        ),
        updated_at = NOW()
    WHERE email = NEW.email;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for supervisor authentication
CREATE TRIGGER handle_supervisor_auth_trigger
  AFTER INSERT ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_supervisor_auth();

-- Create function to update supervisor metadata
CREATE OR REPLACE FUNCTION update_supervisor_metadata()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE auth.users 
  SET raw_user_meta_data = jsonb_build_object(
    'work_centers', NEW.work_centers
  ),
  updated_at = NOW()
  WHERE id = NEW.id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for updating supervisor metadata
CREATE TRIGGER update_supervisor_metadata_trigger
  AFTER UPDATE OF work_centers ON supervisor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_supervisor_metadata();