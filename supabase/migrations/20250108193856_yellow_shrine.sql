/*
  # Add UUID generation function
  
  1. New Functions
    - `generate_uuids`: Function to generate an array of UUIDs
  2. Purpose
    - Provides server-side UUID generation for bulk operations
*/

CREATE OR REPLACE FUNCTION generate_uuids(count integer)
RETURNS uuid[]
LANGUAGE plpgsql
AS $$
DECLARE
  result uuid[];
BEGIN
  SELECT array_agg(gen_random_uuid())
  INTO result
  FROM generate_series(1, count);
  RETURN result;
END;
$$;