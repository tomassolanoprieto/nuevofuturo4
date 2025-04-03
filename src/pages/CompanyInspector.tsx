import React, { useState } from 'react';
import { supabase } from '../lib/supabase';

function InspectorCredentials() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [message, setMessage] = useState('');

  const handleSaveCredentials = async (e) => {
    e.preventDefault();
    setMessage('');

    try {
      // Verificar si ya existen credenciales
      const { data: existingCredentials, error: fetchError } = await supabase
        .from('inspector_credentials')
        .select('*')
        .eq('username', username);

      if (fetchError) throw fetchError;

      if (existingCredentials && existingCredentials.length > 0) {
        throw new Error('El nombre de usuario ya está en uso.');
      }

      // Insertar nuevas credenciales
      const { error } = await supabase
        .from('inspector_credentials')
        .insert([{ username, password }]);

      if (error) throw error;

      setMessage('Credenciales guardadas correctamente.');
      setUsername('');
      setPassword('');
    } catch (error) {
      console.error('Error al guardar credenciales:', error);
      setMessage(error.message);
    }
  };

  return (
    <div className="p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-2xl font-bold mb-4">Configuración del Inspector</h1>
        <p className="text-gray-600 mb-8">
          Define el nombre de usuario y la contraseña para el acceso del Inspector.
        </p>

        <form onSubmit={handleSaveCredentials} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Nombre de Usuario
            </label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Contraseña
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              required
            />
          </div>

          <button
            type="submit"
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            Guardar Credenciales
          </button>
        </form>

        {message && (
          <div className="mt-4 p-4 bg-blue-50 border-l-4 border-blue-500 text-blue-700">
            {message}
          </div>
        )}
      </div>
    </div>
  );
}

export default InspectorCredentials;