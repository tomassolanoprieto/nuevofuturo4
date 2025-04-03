-- Create function to auto-confirm email for company users
CREATE OR REPLACE FUNCTION auto_confirm_company_email()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE auth.users
  SET email_confirmed_at = NOW()
  WHERE id = NEW.id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for auto-confirming company emails
DROP TRIGGER IF EXISTS confirm_company_email ON company_profiles;
CREATE TRIGGER confirm_company_email
  AFTER INSERT ON company_profiles
  FOR EACH ROW
  EXECUTE FUNCTION auto_confirm_company_email();

-- Update existing company users to confirm their emails
DO $$
DECLARE
  comp RECORD;
BEGIN
  FOR comp IN 
    SELECT id FROM company_profiles
  LOOP
    UPDATE auth.users
    SET email_confirmed_at = NOW()
    WHERE id = comp.id;
  END LOOP;
END $$;