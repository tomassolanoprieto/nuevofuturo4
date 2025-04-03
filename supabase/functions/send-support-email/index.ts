import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Log request
    console.log('Received support email request');

    // Parse request body
    const body = await req.json();
    console.log('Request body:', body);

    const { from, name, phone, message, to } = body;

    // Validate required fields
    if (!from || !name || !phone || !message || !to) {
      console.error('Missing required fields:', { from, name, phone, message, to });
      throw new Error('Todos los campos son requeridos');
    }

    // Get API key
    const resendApiKey = Deno.env.get('RESEND_API_KEY');
    if (!resendApiKey) {
      console.error('Missing RESEND_API_KEY environment variable');
      throw new Error('Error de configuración: API key no encontrada');
    }

    // Prepare email data
    const emailData = {
      from: 'Nuevo Futuro <no-reply@nuevofuturo.org>',
      to: to,
      subject: 'Nueva Solicitud de Soporte Técnico',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h1 style="color: #2563eb; margin-bottom: 20px;">Nueva Solicitud de Soporte</h1>
          
          <div style="background-color: #f3f4f6; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
            <h2 style="color: #1f2937; margin-bottom: 15px;">Detalles del Solicitante</h2>
            <p style="margin-bottom: 10px;"><strong>Nombre:</strong> ${name}</p>
            <p style="margin-bottom: 10px;"><strong>Email:</strong> ${from}</p>
            <p style="margin-bottom: 10px;"><strong>Teléfono:</strong> ${phone}</p>
          </div>

          <div style="background-color: #f3f4f6; padding: 20px; border-radius: 8px;">
            <h2 style="color: #1f2937; margin-bottom: 15px;">Descripción del Problema</h2>
            <p style="white-space: pre-wrap;">${message}</p>
          </div>
        </div>
      `
    };

    console.log('Sending email with data:', emailData);

    // Send email
    const resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(emailData),
    });

    const resendData = await resendResponse.json();
    console.log('Resend API response:', resendData);

    if (!resendResponse.ok) {
      console.error('Resend API error:', resendData);
      throw new Error(`Error al enviar el correo: ${resendData.message || 'Error desconocido'}`);
    }

    // Return success response
    return new Response(
      JSON.stringify({ 
        message: 'Solicitud enviada exitosamente',
        id: resendData.id 
      }),
      { 
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json' 
        },
        status: 200,
      },
    );

  } catch (error) {
    // Log error details
    console.error('Error processing request:', error);
    
    // Return error response
    return new Response(
      JSON.stringify({ 
        error: error instanceof Error ? error.message : 'Error desconocido',
        details: error instanceof Error ? error.stack : error
      }),
      { 
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json' 
        },
        status: 400,
      },
    );
  }
});