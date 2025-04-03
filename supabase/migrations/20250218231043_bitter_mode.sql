-- Create function to delete all users
CREATE OR REPLACE FUNCTION delete_all_users()
RETURNS void AS $$
DECLARE
  v_count INTEGER;
BEGIN
  -- First delete from auth.users which will cascade to profiles
  DELETE FROM auth.users;
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % users', v_count;

  -- Reset sequences if any
  ALTER SEQUENCE IF EXISTS auth.users_id_seq RESTART;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute the function
SELECT delete_all_users();

-- Drop the function after use
DROP FUNCTION delete_all_users();