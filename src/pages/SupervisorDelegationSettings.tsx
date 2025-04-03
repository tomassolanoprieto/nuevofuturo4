import React, { useState, useEffect, useRef } from 'react';
import { supabase } from '../lib/supabase';
import { UserPlus, Search, Check, X } from 'lucide-react';

interface Supervisor {
  id: string;
  fiscal_name: string;
  email: string;
  phone: string;
  document_type: string;
  document_number: string;
  supervisor_type: 'center' | 'delegation';
  work_centers: string[];
  delegations: string[];
  pin: string;
  is_active: boolean;
  created_at: string;
}

interface NewSupervisor {
  fiscal_name: string;
  email: string;
  phone: string;
  document_type: string;
  document_number: string;
  supervisor_type: 'center';
  work_centers: string[];
  delegations: string[];
  employee_id: string;
}

const workCenterOptions = [
  "MADRID HOGARES DE EMANCIPACION V. DEL PARDILLO",
  "ALAVA HAZIBIDE",
  "SANTANDER OFICINA",
  "MADRID CUEVAS DE ALMANZORA",
  "SEVILLA ROSALEDA",
  "SEVILLA CASTILLEJA",
  "SANTANDER ALISAL",
  "VALLADOLID MIRLO",
  "MURCIA EL VERDOLAY",
  "BURGOS CERVANTES",
  "MADRID OFICINA",
  "CONCEPCION_LA LINEA CAI / CARMEN HERRERO",
  "CADIZ CARLOS HAYA",
  "MADRID ALCOBENDAS",
  "MADRID MIGUEL HERNANDEZ",
  "MADRID HUMANITARIAS",
  "MADRID VALDEBERNARDO",
  "MADRID JOSE DE PASAMONTE",
  "MADRID IBIZA",
  "MADRID PASEO EXTREMADURA",
  "MADRID INTERVENCION EDUCATIVA",
  "MADRID GABRIEL USERA",
  "MADRID ARROYO DE LAS PILILLAS",
  "MADRID CENTRO DE DIA CARMEN HERRERO",
  "MADRID HOGARES DE EMANCIPACION SANTA CLARA",
  "MADRID HOGARES DE EMANCIPACION BOCANGEL",
  "MADRID AVDA DE AMERICA",
  "MADRID VIRGEN DEL PUIG",
  "MADRID ALMACEN",
  "MADRID HOGARES DE EMANCIPACION ROQUETAS",
  "ALAVA PAULA MONTAL",
  "ALAVA SENDOA",
  "ALAVA EKILORE",
  "ALAVA GESTIÓN AUKERA",
  "ALAVA GESTIÓN HOGARES",
  "ALAVA XABIER",
  "ALAVA ATENCION DIRECTA",
  "ALAVA PROGRAMA DE SEGUIMIENTO",
  "SANTANDER MARIA NEGRETE (CENTRO DE DÍA)",
  "SANTANDER ASTILLERO",
  "BURGOS CORTES",
  "BURGOS ARANDA",
  "BURGOS OFICINA",
  "CONCEPCION_LA LINEA ESPIGON",
  "CONCEPCION_LA LINEA MATILDE GALVEZ",
  "CONCEPCION_LA LINEA GIBRALTAR",
  "CONCEPCION_LA LINEA EL ROSARIO",
  "CONCEPCION_LA LINEA PUNTO DE ENCUENTRO",
  "CONCEPCION_LA LINEA SOROLLA",
  "CADIZ TRILLE",
  "CADIZ GRANJA",
  "CADIZ OFICINA",
  "CADIZ ESQUIVEL",
  "SEVILLA PARAISO",
  "SEVILLA VARIOS",
  "SEVILLA OFICINA",
  "SEVILLA JAP NF+18",
  "MURCIA HOGAR DE SAN ISIDRO",
  "MURCIA HOGAR DE SAN BASILIO",
  "MURCIA OFICINA",
  "ALICANTE EL PINO",
  "ALICANTE EMANCIPACION LOS NARANJOS",
  "ALICANTE EMANCIPACION BENACANTIL",
  "ALICANTE EL POSTIGUET",
  "PALENCIA",
  "CORDOBA CASA HOGAR POLIFEMO",
];

const delegationOptions = [
  "MADRID",
  "ALAVA",
  "SANTANDER",
  "SEVILLA",
  "VALLADOLID",
  "MURCIA",
  "BURGOS",
  "ALICANTE",
  "CONCEPCION_LA",
  "CADIZ",
  "PALENCIA",
  "CORDOBA"
];

export default function SupervisorDelegationSettings() {
  const modalRef = useRef<HTMLDivElement>(null);
  const [supervisors, setSupervisors] = useState<Supervisor[]>([]);
  const [isAddingSuper, setIsAddingSuper] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [newSupervisor, setNewSupervisor] = useState<NewSupervisor>({
    fiscal_name: '',
    email: '',
    phone: '',
    document_type: 'DNI',
    document_number: '',
    supervisor_type: 'center',
    work_centers: [],
    delegations: [],
    employee_id: ''
  });

  // Obtener la delegación del supervisor en curso
  const supervisorEmail = localStorage.getItem('supervisorEmail');
  const currentDelegation = supervisorEmail?.split('@')[0].split('.')[0].toUpperCase();

  // Filtrar centros de trabajo por la delegación del supervisor en curso
  const filteredWorkCenters = workCenterOptions.filter(center =>
    center.startsWith(currentDelegation || '')
  );

  useEffect(() => {
    fetchSupervisors();
  }, []);

  const fetchSupervisors = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      // Obtener solo supervisores de centro de la delegación actual
      const { data, error } = await supabase
        .from('supervisor_profiles')
        .select('*')
        .eq('supervisor_type', 'center')
        .contains('delegations', [currentDelegation])
        .order('created_at', { ascending: false });

      if (error) throw error;
      setSupervisors(data || []);
    } catch (err) {
      console.error('Error fetching supervisors:', err);
    }
  };

  const handleAddSupervisor = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('No se encontró el usuario autenticado');

      // Generar un PIN de 6 dígitos
      const pin = Math.floor(100000 + Math.random() * 900000).toString();

      const { error: insertError } = await supabase
        .from('supervisor_profiles')
        .insert([{
          ...newSupervisor,
          company_id: user.id,
          pin,
          is_active: true,
          delegations: [currentDelegation] // Asignar la delegación actual
        }]);

      if (insertError) throw insertError;

      await fetchSupervisors();
      setIsAddingSuper(false);
      setNewSupervisor({
        fiscal_name: '',
        email: '',
        phone: '',
        document_type: 'DNI',
        document_number: '',
        supervisor_type: 'center',
        work_centers: [],
        delegations: [],
        employee_id: ''
      });

      alert(`Supervisor creado con éxito.\n\nCredenciales para Portal Supervisor:\nEmail: ${newSupervisor.email}\nPIN: ${pin}\n\nPor favor, comparta estas credenciales de forma segura.`);

    } catch (err) {
      console.error('Error adding supervisor:', err);
      setError(err instanceof Error ? err.message : 'Error al añadir supervisor');
    } finally {
      setLoading(false);
    }
  };

  const filteredSupervisors = supervisors.filter(sup =>
    sup.fiscal_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    sup.email.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-8">
      <div className="max-w-7xl mx-auto">
        <div className="bg-white rounded-xl shadow-sm p-6">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-xl font-semibold">Supervisores de Centro</h2>
            <button
              onClick={() => setIsAddingSuper(true)}
              className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
            >
              <UserPlus className="w-5 h-5" />
              Añadir Supervisor
            </button>
          </div>

          <div className="mb-6">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input
                type="text"
                placeholder="Buscar supervisores..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
          </div>

          {/* Supervisors Table */}
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead>
                <tr>
                  <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Nombre
                  </th>
                  <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Email
                  </th>
                  <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Centros de Trabajo
                  </th>
                  <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    PIN
                  </th>
                  <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Estado
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {filteredSupervisors.map((supervisor) => (
                  <tr key={supervisor.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-gray-900">
                        {supervisor.fiscal_name}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-500">
                        {supervisor.email}
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-gray-500">
                        {supervisor.work_centers?.join(', ')}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm font-mono text-gray-900">
                        {supervisor.pin}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium ${
                        supervisor.is_active 
                          ? 'bg-green-100 text-green-800' 
                          : 'bg-red-100 text-red-800'
                      }`}>
                        {supervisor.is_active ? (
                          <>
                            <Check className="w-3 h-3" />
                            Activo
                          </>
                        ) : (
                          <>
                            <X className="w-3 h-3" />
                            Inactivo
                          </>
                        )}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Add Supervisor Modal */}
        {isAddingSuper && (
          <div className="fixed inset-0 overflow-y-auto bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div 
              ref={modalRef}
              className="bg-white rounded-lg p-6 max-w-md w-full my-8"
              style={{ maxHeight: '90vh', overflowY: 'auto' }}
            >
              <div className="flex justify-between items-center mb-4 sticky top-0 bg-white z-10 py-2">
                <h2 className="text-xl font-semibold">Añadir Nuevo Supervisor</h2>
                <button
                  onClick={() => setIsAddingSuper(false)}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <X className="w-6 h-6" />
                </button>
              </div>
              
              {error && (
                <div className="mb-4 p-4 bg-red-50 border-l-4 border-red-500 text-red-700">
                  {error}
                </div>
              )}

              <form onSubmit={handleAddSupervisor} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Nombre
                  </label>
                  <input
                    type="text"
                    value={newSupervisor.fiscal_name}
                    onChange={(e) => setNewSupervisor({...newSupervisor, fiscal_name: e.target.value})}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Email
                  </label>
                  <input
                    type="email"
                    value={newSupervisor.email}
                    onChange={(e) => setNewSupervisor({...newSupervisor, email: e.target.value})}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Teléfono
                  </label>
                  <input
                    type="tel"
                    value={newSupervisor.phone}
                    onChange={(e) => setNewSupervisor({...newSupervisor, phone: e.target.value})}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Tipo de Documento
                  </label>
                  <select
                    value={newSupervisor.document_type}
                    onChange={(e) => setNewSupervisor({...newSupervisor, document_type: e.target.value})}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                  >
                    <option value="DNI">DNI</option>
                    <option value="NIE">NIE</option>
                    <option value="Pasaporte">Pasaporte</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Número de Documento
                  </label>
                  <input
                    type="text"
                    value={newSupervisor.document_number}
                    onChange={(e) => setNewSupervisor({...newSupervisor, document_number: e.target.value})}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Centros de Trabajo
                  </label>
                  <select
                    multiple
                    value={newSupervisor.work_centers}
                    onChange={(e) => {
                      const selectedOptions = Array.from(e.target.selectedOptions, option => option.value);
                      setNewSupervisor({...newSupervisor, work_centers: selectedOptions});
                    }}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                    size={5}
                  >
                    {filteredWorkCenters.map(center => (
                      <option key={center} value={center}>
                        {center}
                      </option>
                    ))}
                  </select>
                  <p className="mt-1 text-sm text-gray-500">
                    Mantén presionado Ctrl (Cmd en Mac) para seleccionar múltiples centros
                  </p>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    ID de Empleado
                  </label>
                  <input
                    type="text"
                    value={newSupervisor.employee_id}
                    onChange={(e) => setNewSupervisor({...newSupervisor, employee_id: e.target.value})}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  />
                </div>

                <div className="flex justify-end gap-4 mt-6 sticky bottom-0 bg-white py-4 border-t">
                  <button
                    type="button"
                    onClick={() => setIsAddingSuper(false)}
                    className="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
                  >
                    Cancelar
                  </button>
                  <button
                    type="submit"
                    disabled={loading}
                    className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
                  >
                    {loading ? 'Añadiendo...' : 'Añadir Supervisor'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}