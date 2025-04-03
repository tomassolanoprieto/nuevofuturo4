-- Drop existing function if exists
DROP FUNCTION IF EXISTS send_pin_email;

-- Create improved function with extensive logging
CREATE OR REPLACE FUNCTION send_pin_email(p_email TEXT, p_pin TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_response JSONB;
  v_status INTEGER;
  v_start_time TIMESTAMPTZ;
  v_end_time TIMESTAMPTZ;
BEGIN
  -- Record start time
  v_start_time := clock_timestamp();
  
  -- Log attempt with timestamp
  RAISE LOG 'PIN email request started at % for email: %', v_start_time, p_email;

  -- Validate inputs
  IF p_email IS NULL OR p_email = '' THEN
    RAISE LOG 'Invalid email address provided';
    RETURN FALSE;
  END IF;

  IF p_pin IS NULL OR p_pin = '' THEN
    RAISE LOG 'Invalid PIN provided';
    RETURN FALSE;
  END IF;

  -- Log API request
  RAISE LOG 'Sending request to Resend API for email: %', p_email;

  -- Send email using pg_net with response capture
  SELECT 
    status,
    response_body::jsonb INTO v_status, v_response
  FROM net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Authorization', 'Bearer re_7YE8fqQo_JAJ2ootxZtSpVDAbS7WTH7uQ',
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

  -- Record end time
  v_end_time := clock_timestamp();

  -- Log detailed response
  RAISE LOG 'Resend API Response:
    Status: %
    Response Body: %
    Request Duration: % seconds', 
    v_status, 
    v_response,
    EXTRACT(EPOCH FROM (v_end_time - v_start_time));

  -- Check response status
  IF v_status >= 200 AND v_status < 300 THEN
    RAISE LOG 'Email sent successfully to % at %', p_email, v_end_time;
    RETURN TRUE;
  ELSE
    RAISE LOG 'Failed to send email. Status: %, Response: %, Time: %', 
      v_status, v_response, v_end_time;
    RETURN FALSE;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    -- Log detailed error information
    RAISE LOG 'Error sending email:
      Email: %
      SQLSTATE: %
      SQLERRM: %
      Time: %', 
      p_email, SQLSTATE, SQLERRM, clock_timestamp();
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION send_pin_email TO authenticated;