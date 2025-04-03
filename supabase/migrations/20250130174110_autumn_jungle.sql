-- Create extension if not exists
CREATE EXTENSION IF NOT EXISTS "pg_net";

-- Create function to send PIN email
CREATE OR REPLACE FUNCTION send_pin_email(p_email TEXT, p_pin TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_response BOOLEAN;
BEGIN
  -- Enviar correo usando pg_net
  PERFORM net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.resend_api_key'),
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'from', 'Nuevo Futuro <no-reply@nuevofuturo.org>',
      'to', p_email,
      'subject', 'Tu PIN de acceso - Nuevo Futuro',
      'html', format('
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h1 style="color: #2563eb; margin-bottom: 20px;">Tu PIN de acceso</h1>
          <p style="margin-bottom: 20px;">Hola,</p>
          <p style="margin-bottom: 20px;">Has solicitado tu PIN de acceso para el Portal de Empleado de Nuevo Futuro.</p>
          <p style="margin-bottom: 20px;">Tu PIN es: <strong style="font-size: 24px; color: #2563eb;">%s</strong></p>
          <p style="margin-bottom: 20px;">Puedes usar este PIN para iniciar sesión en el Portal de Empleado.</p>
          <p style="color: #666; font-size: 14px;">Por razones de seguridad, te recomendamos no compartir este PIN con nadie.</p>
        </div>
      ', p_pin)
    )
  );

  -- Return success
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error and return false
    RAISE NOTICE 'Error sending email: %', SQLERRM;
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION send_pin_email TO authenticated;

-- Create policy to allow employees to use the function
CREATE POLICY "Allow employees to use send_pin_email"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (
    email = current_setting('request.jwt.claims')::json->>'email'
    AND is_active = true
  );