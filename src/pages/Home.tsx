import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Building, Users, Shield, Send } from 'lucide-react';
import emailjs from '@emailjs/browser';
import logoNF from '../lib/AF_NF_rgb.fw.png';

interface SupportForm {
  fullName: string;
  email: string;
  phone: string;
  description: string;
}

export default function Home() {
  const navigate = useNavigate();
  const [showForm, setShowForm] = useState(false);
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState<SupportForm>({
    fullName: '',
    email: '',
    phone: '',
    description: ''
  });
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const result = await emailjs.send(
        'service_5z1qv9z',
        'template_wtvrquq',
        {
          from_name: formData.fullName,
          from_email: formData.email,
          phone: formData.phone,
          message: formData.description,
          to_email: 'mgonzalez@controlaltsup.com, tomas.solano@rtsgroup.es'
        },
        'YsQMH1h7gxb7yObr_'
      );

      if (result.status === 200) {
        setSuccess(true);
        setFormData({
          fullName: '',
          email: '',
          phone: '',
          description: ''
        });
      } else {
        throw new Error('Error al enviar el formulario');
      }
    } catch (error) {
      console.error('Error sending support email:', error);
      setError('Error al enviar el formulario. Por favor, inténtelo de nuevo.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-green-50 via-white to-green-50">
      {/* Hero Section */}
      <div className="container mx-auto px-4 pt-20 pb-32">
        <div className="text-center mb-16">
          <div className="flex justify-center mb-12">
            <img 
              src={logoNF}
              alt="Nuevo Futuro Logo" 
              className="h-32 w-auto object-contain"
            />
          </div>
          
          <div className="max-w-2xl mx-auto">
            <div className="grid grid-cols-2 gap-4">
              <button
                onClick={() => navigate('/login/empresa')}
                className="bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 px-6 rounded-lg shadow-md transition duration-300 flex items-center justify-center gap-2"
              >
                <Building className="w-5 h-5" />
                Empresa
              </button>
              
              <button
                onClick={() => navigate('/login/empleado')}
                className="bg-green-600 hover:bg-green-700 text-white font-semibold py-3 px-6 rounded-lg shadow-md transition duration-300 flex items-center justify-center gap-2"
              >
                <Users className="w-5 h-5" />
                Trabajador/a
              </button>

              <button
                onClick={() => navigate('/login/supervisor/delegacion')}
                className="bg-purple-600 hover:bg-purple-700 text-white font-semibold py-3 px-6 rounded-lg shadow-md transition duration-300 flex items-center justify-center gap-2"
              >
                <Shield className="w-5 h-5" />
                Supervisor/a Delegación
              </button>

              <button
                onClick={() => navigate('/login/supervisor/centro')}
                className="bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-3 px-6 rounded-lg shadow-md transition duration-300 flex items-center justify-center gap-2"
              >
                <Shield className="w-5 h-5" />
                Supervisor/a Centro
              </button>

              {/* Botón del Inspector centrado */}
              <div className="col-span-2 flex justify-center">
                <button
                  onClick={() => navigate('/login/inspector')}
                  className="bg-yellow-600 hover:bg-yellow-700 text-white font-semibold py-3 px-6 rounded-lg shadow-md transition duration-300 flex items-center justify-center gap-2"
                >
                  <Shield className="w-5 h-5" />
                  Inspector/a
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Support Button */}
        <div className="text-center mb-16">
          <button
            onClick={() => setShowForm(true)}
            className="inline-flex items-center gap-2 px-6 py-3 bg-orange-600 text-white font-semibold rounded-lg shadow-md hover:bg-orange-700 transition duration-300"
          >
            <Send className="w-5 h-5" />
            Soporte Técnico
          </button>
        </div>

        {/* Support Form Modal */}
        {showForm && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-lg p-6 max-w-md w-full">
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-xl font-semibold">Formulario de Soporte</h2>
                <button
                  onClick={() => setShowForm(false)}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <span className="sr-only">Cerrar</span>
                  <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              {error && (
                <div className="mb-4 p-4 bg-red-50 border-l-4 border-red-500 text-red-700">
                  {error}
                </div>
              )}

              {success ? (
                <div className="text-center py-8">
                  <div className="mb-4 text-green-600">
                    <svg className="w-16 h-16 mx-auto" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                  </div>
                  <h3 className="text-xl font-medium text-gray-900 mb-2">
                    ¡Formulario enviado con éxito!
                  </h3>
                  <p className="text-gray-600 mb-6">
                    Nos pondremos en contacto contigo lo antes posible.
                  </p>
                  <button
                    onClick={() => {
                      setShowForm(false);
                      setSuccess(false);
                    }}
                    className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                  >
                    Cerrar
                  </button>
                </div>
              ) : (
                <form onSubmit={handleSubmit} className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Nombre Completo
                    </label>
                    <input
                      type="text"
                      value={formData.fullName}
                      onChange={(e) => setFormData({...formData, fullName: e.target.value})}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      required
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Correo Electrónico
                    </label>
                    <input
                      type="email"
                      value={formData.email}
                      onChange={(e) => setFormData({...formData, email: e.target.value})}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      required
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Número de Teléfono
                    </label>
                    <input
                      type="tel"
                      value={formData.phone}
                      onChange={(e) => setFormData({...formData, phone: e.target.value})}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      required
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Descripción del Soporte Necesario
                    </label>
                    <textarea
                      value={formData.description}
                      onChange={(e) => setFormData({...formData, description: e.target.value})}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      rows={4}
                      required
                    />
                  </div>

                  <div className="flex justify-end gap-4 mt-6">
                    <button
                      type="button"
                      onClick={() => setShowForm(false)}
                      className="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
                    >
                      Cancelar
                    </button>
                    <button
                      type="submit"
                      disabled={loading}
                      className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
                    >
                      {loading ? 'Enviando...' : 'Enviar'}
                    </button>
                  </div>
                </form>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Footer */}
      <footer className="bg-white py-8">
        <div className="container mx-auto px-4 text-center text-gray-600">
          <p>© {new Date().getFullYear()} Control Alt Sup. Todos los derechos reservados.</p>
        </div>
      </footer>
    </div>
  );
}