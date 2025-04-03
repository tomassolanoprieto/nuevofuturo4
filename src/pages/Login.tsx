import React, { useState } from 'react';
import { Link, useParams, useNavigate, useLocation } from 'react-router-dom';
import { Clock, ArrowLeft, Shield } from 'lucide-react';
import { supabase } from '../lib/supabase';
import emailjs from '@emailjs/browser';

function Login() {
  const { portal } = useParams();
  const navigate = useNavigate();
  const location = useLocation();
  const portalTitle = portal === 'empresa' ? 'Empresa' : 
                     portal === 'supervisor' ? 'Supervisor/a' : 
                     portal === 'inspector' ? 'Inspector/a' : 
                     'Trabajador/a'; // Cambiado de "Empleado" a "Trabajador/a"
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [recoveryEmail, setRecoveryEmail] = useState('');
  const [recoverySuccess, setRecoverySuccess] = useState(false);
  const [showRecovery, setShowRecovery] = useState(false);
  const [formData, setFormData] = useState({
    email: '',
    password: ''
  });

  // Determinar el tipo de supervisor
  const isSupervisorDelegation = location.pathname.includes('supervisor/delegacion');
  const isSupervisorCenter = location.pathname.includes('supervisor/centro');
  const supervisorType = isSupervisorDelegation ? 'delegation' : 'center';

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      if (location.pathname.includes('inspector')) {
        // Verificar credenciales del Inspector/a
        const { data: inspectorData, error: inspectorError } = await supabase
          .from('inspector_credentials')
          .select('*')
          .eq('username', formData.email)
          .eq('password', formData.password)
          .single();

        if (inspectorError || !inspectorData) {
          throw new Error('Credenciales inválidas');
        }

        // Redirigir al Dashboard del Inspector/a
        navigate('/inspector');
      } else if (location.pathname.includes('supervisor')) {
        // Verificar credenciales del Supervisor/a
        const { data: supervisorData, error: supervisorError } = await supabase
          .from('supervisor_profiles')
          .select('*')
          .eq('email', formData.email)
          .eq('pin', formData.password)
          .eq('is_active', true)
          .single();

        if (supervisorError || !supervisorData) {
          throw new Error('Credenciales inválidas');
        }

        // Almacenar el correo electrónico y el tipo de supervisor/a en localStorage
        localStorage.setItem('supervisorEmail', supervisorData.email);
        localStorage.setItem('supervisorType', supervisorType);

        // Redirigir según el tipo de supervisor/a
        if (supervisorType === 'delegation') {
          navigate('/supervisor/delegacion');
        } else {
          navigate('/supervisor/centro');
        }
      } else if (portal === 'empleado') {
        // Verificar credenciales del Trabajador/a
        const { data: employeeData, error: employeeError } = await supabase
          .from('employee_profiles')
          .select('*')
          .eq('email', formData.email)
          .eq('pin', formData.password)
          .eq('is_active', true)
          .single();

        if (employeeError || !employeeData) {
          throw new Error('Credenciales inválidas');
        }

        // Crear sesión usando RLS bypass function
        const { data: sessionData, error: sessionError } = await supabase
          .rpc('verify_employee_credentials', {
            p_email: formData.email,
            p_pin: formData.password
          });

        if (sessionError) throw sessionError;

        // Almacenar el ID del trabajador/a en localStorage
        localStorage.setItem('employeeId', employeeData.id);

        navigate('/empleado');
      } else {
        // Verificar credenciales de la Empresa
        const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
          email: formData.email,
          password: formData.password
        });

        if (authError) throw authError;
        if (!authData.user) throw new Error('Error de autenticación');

        const { data: companyData, error: companyError } = await supabase
          .from('company_profiles')
          .select('*')
          .eq('id', authData.user.id)
          .single();

        if (companyError || !companyData) {
          await supabase.auth.signOut();
          throw new Error('Usuario no autorizado');
        }

        navigate('/empresa');
      }
    } catch (err) {
      console.error('Error de inicio de sesión:', err);
      setError(err instanceof Error ? err.message : 'Credenciales inválidas');
      if (!location.pathname.includes('supervisor')) {
        await supabase.auth.signOut();
      }
    } finally {
      setLoading(false);
    }
  };

  const handleRecoverySubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setRecoverySuccess(false);

    try {
      // Obtener el PIN del trabajador/a
      const { data: employeeData, error: employeeError } = await supabase
        .from('employee_profiles')
        .select('pin, email')
        .eq('email', recoveryEmail)
        .eq('is_active', true)
        .single();

      if (employeeError || !employeeData?.pin) {
        throw new Error('No se encontró ningún trabajador/a activo con ese email');
      }

      // Enviar correo con el PIN usando EmailJS
      const result = await emailjs.send(
        'service_5z1qv9z',
        'template_4nvqnw5',
        {
          to_email: employeeData.email,
          pin: employeeData.pin
        },
        'YsQMH1h7gxb7yObr_'
      );

      if (result.status === 200) {
        setRecoverySuccess(true);
        setRecoveryEmail('');
      } else {
        throw new Error('Error al enviar el correo');
      }
    } catch (err) {
      console.error('Error en recuperación de PIN:', err);
      setError('No se pudo procesar la solicitud. Por favor, verifica que el correo sea correcto.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-blue-50 to-white flex items-center justify-center px-4">
      <button
        onClick={() => navigate('/')}
        className="absolute top-4 left-4 flex items-center gap-2 px-4 py-2 text-gray-600 hover:text-gray-900 bg-white rounded-lg shadow-sm hover:shadow transition-all"
      >
        <ArrowLeft className="w-5 h-5" />
        Volver al Inicio
      </button>

      <div className="bg-white p-8 rounded-xl shadow-xl max-w-md w-full">
        <div className="text-center mb-8">
          {location.pathname.includes('supervisor') ? (
            <Shield className="w-12 h-12 text-purple-600 mx-auto mb-4" />
          ) : (
            <Clock className="w-12 h-12 text-blue-600 mx-auto mb-4" />
          )}
          <h2 className="text-2xl font-bold text-gray-900">
            Portal {isSupervisorDelegation ? 'Supervisor/a Delegación' : 
                   isSupervisorCenter ? 'Supervisor/a Centro' : 
                   portalTitle}
          </h2>
          <p className="text-gray-600">Inicia sesión en tu cuenta</p>
        </div>

        {error && (
          <div className="mb-4 p-4 bg-red-50 border-l-4 border-red-500 text-red-700">
            {error}
          </div>
        )}

        {recoverySuccess && (
          <div className="mb-4 p-4 bg-green-50 border-l-4 border-green-500 text-green-700">
            Se ha enviado un correo con tu PIN.
          </div>
        )}

        {showRecovery ? (
          <form onSubmit={handleRecoverySubmit} className="space-y-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Correo Electrónico
              </label>
              <input
                type="email"
                value={recoveryEmail}
                onChange={(e) => setRecoveryEmail(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                required
              />
            </div>

            <div className="flex flex-col gap-2">
              <button
                type="submit"
                disabled={loading}
                className="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 rounded-lg transition duration-300 disabled:opacity-50"
              >
                {loading ? 'Enviando...' : 'Enviar PIN'}
              </button>
              <button
                type="button"
                onClick={() => setShowRecovery(false)}
                className="w-full bg-gray-100 hover:bg-gray-200 text-gray-700 font-semibold py-3 rounded-lg transition duration-300"
              >
                Volver al inicio de sesión
              </button>
            </div>
          </form>
        ) : (
          <form className="space-y-6" onSubmit={handleSubmit}>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                {location.pathname.includes('inspector') ? 'Usuario' : 'Correo Electrónico'}
              </label>
              <input
                type={location.pathname.includes('inspector') ? 'text' : 'email'}
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                {location.pathname.includes('inspector') ? 'Contraseña' : (portal === 'empresa' ? 'Contraseña' : 'PIN')}
              </label>
              <input
                type="password"
                value={formData.password}
                onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                required
              />
              {!location.pathname.includes('inspector') && portal !== 'empresa' && (
                <p className="mt-1 text-sm text-gray-500">
                  Ingresa el PIN de 6 dígitos proporcionado
                </p>
              )}
            </div>

            <button
              type="submit"
              disabled={loading}
              className={`w-full ${
                location.pathname.includes('supervisor') ? 'bg-purple-600 hover:bg-purple-700' : 'bg-blue-600 hover:bg-blue-700'
              } text-white font-semibold py-3 rounded-lg transition duration-300 disabled:opacity-50`}
            >
              {loading ? 'Iniciando sesión...' : 'Iniciar Sesión'}
            </button>

            {portal === 'empleado' && (
              <button
                type="button"
                onClick={() => setShowRecovery(true)}
                className="w-full text-blue-600 hover:text-blue-800 text-sm"
              >
                ¿Olvidaste tu PIN?
              </button>
            )}
          </form>
        )}

        {portal === 'empresa' && (
          <p className="mt-6 text-center text-gray-600">
            ¿No tienes una cuenta?{' '}
            <Link
              to={`/register/${portal}`}
              className="text-blue-600 hover:text-blue-800 font-semibold"
            >
              Regístrate
            </Link>
          </p>
        )}
      </div>
    </div>
  );
}

export default Login;