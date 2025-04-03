import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.8';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { email } = await req.json();

    if (!email) {
      throw new Error('Email es requerido');
    }

    // Verificar variables de entorno
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const resendApiKey = Deno.env.get('RESEND_API_KEY');

    if (!supabaseUrl || !supabaseAnonKey) {
      throw new Error('Error de configuración de Supabase');
    }

    if (!resendApiKey) {
      throw new Error('Error de configuración de Resend');
    }

    // Crear cliente de Supabase
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      auth: { persistSession: false }
    });

    // Buscar el empleado
    const { data: employee, error: employeeError } = await supabaseClient
      .from('employee_profiles')
      .select('email, pin')
      .eq('email', email)
      .eq('is_active', true)
      .single();

    if (employeeError) {
      console.error('Error buscando empleado:', employeeError);
      throw new Error('Error al buscar el empleado');
    }

    if (!employee) {
      throw new Error('No se encontró ningún empleado activo con ese email');
    }

    if (!employee.pin) {
      throw new Error('El empleado no tiene un PIN configurado');
    }

    // Enviar correo usando Resend
    const resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'Nuevo Futuro <no-reply@nuevofuturo.org>',
        to: employee.email,
        subject: 'Tu PIN de acceso - Nuevo Futuro',
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <h1 style="color: #2563eb; margin-bottom: 20px;">Tu PIN de acceso</h1>
            <p style="margin-bottom: 20px;">Hola,</p>
            <p style="margin-bottom: 20px;">Has solicitado tu PIN de acceso para el Portal de Empleado de Nuevo Futuro.</p>
            <p style="margin-bottom: 20px;">Tu PIN es: <strong style="font-size: 24px; color: #2563eb;">${employee.pin}</strong></p>
            <p style="margin-bottom: 20px;">Puedes usar este PIN para iniciar sesión en el Portal de Empleado.</p>
            <p style="color: #666; font-size: 14px;">Por razones de seguridad, te recomendamos no compartir este PIN con nadie.</p>
          </div>
        `,
      }),
    });

    const resendData = await resendResponse.json();

    if (!resendResponse.ok) {
      console.error('Error de Resend:', resendData);
      throw new Error(`Error al enviar el correo: ${resendData.message || 'Error desconocido'}`);
    }

    return new Response(
      JSON.stringify({ message: 'Correo enviado exitosamente' }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    );

  } catch (error) {
    console.error('Error detallado:', error);
    return new Response(
      JSON.stringify({ 
        error: error instanceof Error ? error.message : 'Error desconocido',
        details: error instanceof Error ? error.stack : error
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    );
  }
});