/*
  # Authentication and Profiles Schema

  1. New Tables
    - `company_profiles`
      - `id` (uuid, primary key, references auth.users)
      - `fiscal_name` (text)
      - `phone` (text)
      - `country` (text)
      - `timezone` (text)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `employee_profiles`
      - `id` (uuid, primary key, references auth.users)
      - `fiscal_name` (text)
      - `phone` (text)
      - `country` (text)
      - `timezone` (text)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on both tables
    - Add policies for user access
*/

-- Create company profiles table
CREATE TABLE IF NOT EXISTS company_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fiscal_name TEXT NOT NULL,
  phone TEXT,
  country TEXT NOT NULL,
  timezone TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create employee profiles table
CREATE TABLE IF NOT EXISTS employee_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fiscal_name TEXT NOT NULL,
  phone TEXT,
  country TEXT NOT NULL,
  timezone TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE company_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_profiles ENABLE ROW LEVEL SECURITY;

-- Policies for company profiles
CREATE POLICY "Users can view own company profile" 
  ON company_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update own company profile"
  ON company_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own company profile"
  ON company_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Policies for employee profiles
CREATE POLICY "Users can view own employee profile"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update own employee profile"
  ON employee_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own employee profile"
  ON employee_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);