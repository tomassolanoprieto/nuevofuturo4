import React, { useState, useEffect, useRef } from 'react';
import { supabase } from '../lib/supabase';
import { UserPlus, UserX, Download, Upload, Search, Check, X, Edit, Save, Trash } from 'lucide-react';

interface Employee {
  id: string;
  fiscal_name: string;
  email: string;
  is_active: boolean;
  created_at: string;
  document_type: string;
  document_number: string;
  work_centers: string[];
  delegation: string;
  pin: string;
  employee_id: string;
  seniority_date: string;
  job_positions: string[];
  country: string;
  timezone: string;
  phone: string;
}

interface NewEmployee {
  fiscal_name: string;
  email: string;
  document_type: string;
  document_number: string;
  work_centers: string[];
  delegation: string;
  country: string;
  timezone: string;
  phone: string;
  employee_id: string;
  seniority_date: string;
  job_positions: string[];
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

const jobPositions = [
  "EDUCADOR/A SOCIAL",
  "AUX. TÉCNICO/A EDUCATIVO/A",
  "GERENTE",
  "DIRECTOR EMANCIPACION",
  "PSICOLOGO/A",
  "ADMINISTRATIVO/A",
  "EDUCADOR/A RESPONSABLE",
  "TEC. INT. SOCIAL",
  "APOYO DOMESTICO",
  "OFICIAL/A DE MANTENIMIENTO",
  "PEDAGOGO/A",
  "CONTABLE",
  "TRABAJADOR/A SOCIAL",
  "COCINERO/A",
  "COORDINADOR/A",
  "DIRECTOR/A HOGAR",
  "RESPONSABLE HOGAR",
  "AUX. SERV. GRALES",
  "ADVO/A. CONTABLE",
  "LIMPIADOR/A",
  "AUX. ADMVO/A",
  "DIRECTOR/A",
  "JEFE/A ADMINISTRACIÓN",
  "DIRECTORA POSTACOGIMIENTO",
  "COORD. TERRITORIAL CASTILLA Y LEON",
  "DIRECTOR COMUNICACION",
  "AUX. GEST. ADVA",
  "RESPONSABLE RRHH",
  "COORD. TERRITORIAL ANDALUCIA"
];

export default function CompanyEmployees() {
  const modalRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [selectedEmployees, setSelectedEmployees] = useState<string[]>([]);
  const [showActive, setShowActive] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [isAdding, setIsAdding] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [newEmployee, setNewEmployee] = useState<NewEmployee>({
    fiscal_name: '',
    email: '',
    document_type: 'DNI',
    document_number: '',
    work_centers: [],
    delegation: '',
    country: 'España',
    timezone: 'Europe/Madrid',
    phone: '',
    employee_id: '',
    seniority_date: '',
    job_positions: []
  });
  const [editingEmployeeId, setEditingEmployeeId] = useState<string | null>(null);
  const [editingEmployeeData, setEditingEmployeeData] = useState<Employee | null>(null);

  const employeesPerPage = 25;

  useEffect(() => {
    fetchEmployees();
  }, [showActive]);

  const fetchEmployees = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data } = await supabase
        .from('employee_profiles')
        .select('*')
        .eq('company_id', user.id)
        .eq('is_active', showActive)
        .order('fiscal_name', { ascending: true });

      if (data) {
        setEmployees(data);
      }
    } catch (err) {
      console.error('Error fetching employees:', err);
    }
  };

  const handleEditClick = (employee: Employee) => {
    setEditingEmployeeId(employee.id);
    setEditingEmployeeData(employee);
  };

  const handleSaveClick = async () => {
    if (!editingEmployeeData) return;

    try {
      setLoading(true);
      setError(null);

      const { error } = await supabase
        .from('employee_profiles')
        .update(editingEmployeeData)
        .eq('id', editingEmployeeData.id);

      if (error) throw error;

      await fetchEmployees();
      setEditingEmployeeId(null);
      setEditingEmployeeData(null);
    } catch (err) {
      console.error('Error updating employee:', err);
      setError(err instanceof Error ? err.message : 'Error al actualizar empleado');
    } finally {
      setLoading(false);
    }
  };

  const handleCancelClick = () => {
    setEditingEmployeeId(null);
    setEditingEmployeeData(null);
  };

  const handleInputChange = (field: keyof Employee, value: string | string[]) => {
    if (editingEmployeeData) {
      setEditingEmployeeData({ ...editingEmployeeData, [field]: value });
    }
  };

  const handleAddEmployee = async () => {
    try {
      setLoading(true);
      setError(null);

      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('No se encontró el usuario autenticado');

      const { error } = await supabase
        .from('employee_profiles')
        .insert([{
          ...newEmployee,
          company_id: user.id,
          is_active: true
        }]);

      if (error) throw error;

      await fetchEmployees();
      setIsAdding(false);
      setNewEmployee({
        fiscal_name: '',
        email: '',
        document_type: 'DNI',
        document_number: '',
        work_centers: [],
        delegation: '',
        country: 'España',
        timezone: 'Europe/Madrid',
        phone: '',
        employee_id: '',
        seniority_date: '',
        job_positions: []
      });

    } catch (err) {
      console.error('Error adding employee:', err);
      setError(err instanceof Error ? err.message : 'Error al añadir empleado');
    } finally {
      setLoading(false);
    }
  };

  const handleDeactivateSelected = async () => {
    try {
      setLoading(true);

      const { error: updateError } = await supabase
        .from('employee_profiles')
        .update({ is_active: false })
        .in('id', selectedEmployees);

      if (updateError) {
        throw updateError;
      }

      setShowActive(false);
      await fetchEmployees();
      setSelectedEmployees([]);
      
      alert('Empleados desactivados correctamente');
    } catch (err) {
      console.error('Error deactivating employees:', err);
      alert('Error al desactivar empleados');
    } finally {
      setLoading(false);
    }
  };

  const handleActivateSelected = async () => {
    try {
      setLoading(true);

      const { error: updateError } = await supabase
        .from('employee_profiles')
        .update({ is_active: true })
        .in('id', selectedEmployees);

      if (updateError) {
        throw updateError;
      }

      setShowActive(true);
      await fetchEmployees();
      setSelectedEmployees([]);
      
      alert('Empleados reactivados correctamente');
    } catch (err) {
      console.error('Error reactivating employees:', err);
      alert('Error al reactivar empleados');
    } finally {
      setLoading(false);
    }
  };

  const handleExportEmployees = () => {
    const csvContent = [
      ['ID', 'Nombre', 'Tipo Documento', 'Documento', 'Email', 'Centros de Trabajo', 'Delegación', 'Fecha Incorporación', 'Fecha Antigüedad', 'Estado', 'Puestos de Trabajo'],
      ...employees.map(emp => [
        emp.employee_id,
        emp.fiscal_name,
        emp.document_type,
        emp.document_number,
        emp.email,
        emp.work_centers.join('; '),
        emp.delegation,
        new Date(emp.created_at).toLocaleDateString(),
        emp.seniority_date ? new Date(emp.seniority_date).toLocaleDateString() : '',
        emp.is_active ? 'Activo' : 'Inactivo',
        emp.job_positions ? emp.job_positions.join('; ') : ''
      ])
    ].map(row => row.join(',')).join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'empleados.csv';
    link.click();
  };

  const handleImportEmployees = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target?.files?.[0];
    if (!file) return;

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const reader = new FileReader();
      reader.onload = async (e) => {
        const text = e.target?.result as string;
        const rows = text.split('\n').slice(1); // Skip header row

        for (const row of rows) {
          try {
            const [
              employee_id,
              fiscal_name,
              document_type,
              document_number,
              email,
              work_center,
              delegation,
              seniority_date,
              job_position
            ] = row.split(',').map(field => field.trim().replace(/^"|"$/g, ''));

            // Skip empty rows
            if (!fiscal_name || !email) continue;

            // Parse work centers
            const work_centers = work_center ? [work_center] : [];

            // Parse job positions
            const job_positions = job_position ? [job_position] : [];

            // Parse and validate seniority date
            let formattedSeniorityDate = null;
            if (seniority_date) {
              try {
                const [day, month, year] = seniority_date.split('/');
                if (day && month && year) {
                  formattedSeniorityDate = `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
                  
                  // Validate date
                  if (isNaN(Date.parse(formattedSeniorityDate))) {
                    formattedSeniorityDate = null;
                  }
                }
              } catch (err) {
                console.warn('Invalid date format:', seniority_date);
                formattedSeniorityDate = null;
              }
            }

            // Create employee profile
            const { error: profileError } = await supabase
              .from('employee_profiles')
              .insert([{
                employee_id: employee_id || '',
                fiscal_name,
                email: email.toLowerCase(),
                document_type: document_type || 'DNI',
                document_number: document_number || '',
                work_centers,
                delegation: delegation || 'Madrid',
                country: 'España',
                timezone: 'Europe/Madrid',
                seniority_date: formattedSeniorityDate,
                job_positions,
                company_id: user.id,
                is_active: true
              }]);

            if (profileError) {
              console.error('Error importing employee:', profileError);
              continue;
            }

          } catch (err) {
            console.error('Error processing row:', err);
            continue;
          }
        }

        await fetchEmployees();
        
        // Reset file input
        if (fileInputRef.current) {
          fileInputRef.current.value = '';
        }
      };
      reader.readAsText(file);
    } catch (err) {
      console.error('Error in handleImportEmployees:', err);
    }
  };

  const handleAddClick = () => {
    setIsAdding(true);
    document.body.style.overflow = 'hidden';
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleCloseModal = () => {
    setIsAdding(false);
    document.body.style.overflow = 'unset';
    setNewEmployee({
      fiscal_name: '',
      email: '',
      document_type: 'DNI',
      document_number: '',
      work_centers: [],
      delegation: '',
      country: 'España',
      timezone: 'Europe/Madrid',
      phone: '',
      employee_id: '',
      seniority_date: '',
      job_positions: []
    });
  };

  const filteredEmployees = employees.filter(emp => 
    emp.fiscal_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    emp.email.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const totalPages = Math.ceil(filteredEmployees.length / employeesPerPage);
  const currentEmployees = filteredEmployees.slice(
    (currentPage - 1) * employeesPerPage,
    currentPage * employeesPerPage
  );

  return (
    <div className="p-8">
      <div className="mb-6 flex flex-wrap gap-4 items-center justify-between">
        <div className="flex gap-4">
          <button
            onClick={handleAddClick}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            <UserPlus className="w-5 h-5" />
            Añadir un nuevo empleado
          </button>
          {showActive ? (
            <button
              onClick={handleDeactivateSelected}
              disabled={selectedEmployees.length === 0 || loading}
              className="flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <UserX className="w-5 h-5" />
              Desactivar Seleccionados
            </button>
          ) : (
            <button
              onClick={handleActivateSelected}
              disabled={selectedEmployees.length === 0 || loading}
              className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Check className="w-5 h-5" />
              Activar Seleccionados
            </button>
          )}
          <button
            onClick={handleExportEmployees}
            className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
          >
            <Download className="w-5 h-5" />
            Exportar empleados
          </button>
          <div className="relative">
            <input
              type="file"
              accept=".csv"
              onChange={handleImportEmployees}
              className="hidden"
              id="import-file"
              ref={fileInputRef}
            />
            <label
              htmlFor="import-file"
              className="flex items-center gap-2 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors cursor-pointer"
            >
              <Upload className="w-5 h-5" />
              Importar empleados
            </label>
          </div>
        </div>

        <div className="flex gap-4">
          <button
            onClick={() => setShowActive(true)}
            className={`px-4 py-2 rounded-lg ${
              showActive 
                ? 'bg-blue-600 text-white' 
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            Usuarios activos
          </button>
          <button
            onClick={() => setShowActive(false)}
            className={`px-4 py-2 rounded-lg ${
              !showActive 
                ? 'bg-blue-600 text-white' 
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            Usuarios inactivos
          </button>
        </div>
      </div>

      <div className="mb-6">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
          <input
            type="text"
            placeholder="Buscar empleados..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          />
        </div>
      </div>

      {isAdding && (
        <div 
          className="fixed inset-0 overflow-y-auto bg-black bg-opacity-50 z-50"
          style={{ paddingTop: '2vh', paddingBottom: '2vh' }}
        >
          <div className="flex items-center justify-center min-h-full p-4">
            <div 
              ref={modalRef}
              className="bg-white rounded-lg p-6 max-w-md w-full my-8"
            >
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-xl font-semibold">Añadir Nuevo Empleado</h2>
                <button
                  onClick={handleCloseModal}
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

              <form onSubmit={(e) => { e.preventDefault(); handleAddEmployee(); }} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    ID Empleado
                  </label>
                  <input
                    type="text"
                    value={newEmployee.employee_id}
                    onChange={(e) => setNewEmployee({...newEmployee, employee_id: e.target.value})}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Fecha de Antigüedad
                  </label>
                  <input
                    type="date"
                    value={newEmployee.seniority_date}
                    onChange={(e) => setNewEmployee({...newEmployee, seniority_date: e.target.value})}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Nombre
                  </label>
                  <input
                    type="text"
                    value={newEmployee.fiscal_name}
                    onChange={(e) => setNewEmployee({...newEmployee, fiscal_name: e.target.value})}
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
                    value={newEmployee.email}
                    onChange={(e) => setNewEmployee({...newEmployee, email: e.target.value})}
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
                    value={newEmployee.phone}
                    onChange={(e) => setNewEmployee({...newEmployee, phone: e.target.value})}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Tipo de Documento
                  </label>
                  <select
                    value={newEmployee.document_type}
                    onChange={(e) => setNewEmployee({...newEmployee, document_type: e.target.value})}
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
                    value={newEmployee.document_number}
                    onChange={(e) => setNewEmployee({...newEmployee, document_number: e.target.value})}
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
                    value={newEmployee.work_centers}
                    onChange={(e) => {
                      const selectedOptions = Array.from(e.target.selectedOptions, option => option.value);
                      setNewEmployee({...newEmployee, work_centers: selectedOptions});
                    }}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                    size={5}
                  >
                    {workCenterOptions.map(center => (
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
                    Puesto de Trabajo
                  </label>
                  <select
                    multiple
                    value={newEmployee.job_positions}
                    onChange={(e) => {
                      const selectedOptions = Array.from(e.target.selectedOptions, option => option.value);
                      setNewEmployee({...newEmployee, job_positions: selectedOptions});
                    }}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                    size={5}
                  >
                    {jobPositions.map(position => (
                      <option key={position} value={position}>
                        {position}
                      </option>
                    ))}
                  </select>
                  <p className="mt-1 text-sm text-gray-500">
                    Mantén presionado Ctrl (Cmd en Mac) para seleccionar múltiples puestos
                  </p>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Delegación
                  </label>
                  <select
                    value={newEmployee.delegation}
                    onChange={(e) => setNewEmployee({...newEmployee, delegation: e.target.value})}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                  >
                    <option value="">Selecciona una delegación</option>
                    {delegationOptions.map(delegation => (
                      <option key={delegation} value={delegation}>
                        {delegation}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="flex justify-end gap-4 mt-6">
                  <button
                    type="button"
                    onClick={handleCloseModal}
                    className="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
                  >
                    Cancelar
                  </button>
                  <button
                    type="submit"
                    disabled={loading}
                    className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
                  >
                    {loading ? 'Añadiendo...' : 'Añadir Empleado'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}

      <div className="bg-white rounded-lg shadow overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead>
            <tr>
              <th className="px-6 py-3 bg-gray-50 text-left">
                <input
                  type="checkbox"
                  checked={selectedEmployees.length === currentEmployees.length}
                  onChange={(e) => {
                    if (e.target.checked) {
                      setSelectedEmployees(currentEmployees.map(emp => emp.id));
                    } else {
                      setSelectedEmployees([]);
                    }
                  }}
                  className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                />
              </th>
              <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                ID
              </th>
              <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Nombre
              </th>
              <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Tipo Documento
              </th>
              <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Documento
              </th>
              <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Email
              </th>
              <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Centros de Trabajo
              </th>
              <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Delegación
              </th>
              <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                PIN
              </th>
              <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Fecha Incorporación
              </th>
              <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Fecha Antigüedad
              </th>
              <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Puestos de Trabajo
              </th>
              <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Estado
              </th>
              <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Acciones
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {currentEmployees.map((employee) => (
              <tr key={employee.id} className="hover:bg-gray-50">
                <td className="px-6 py-4">
                  <input
                    type="checkbox"
                    checked={selectedEmployees.includes(employee.id)}
                    onChange={(e) => {
                      if (e.target.checked) {
                        setSelectedEmployees([...selectedEmployees, employee.id]);
                      } else {
                        setSelectedEmployees(selectedEmployees.filter(id => id !== employee.id));
                      }
                    }}
                    className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                  />
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  {editingEmployeeId === employee.id ? (
                    <input
                      type="text"
                      value={editingEmployeeData?.employee_id || ''}
                      onChange={(e) => handleInputChange('employee_id', e.target.value)}
                      className="w-full px-2 py-1 border border-gray-300 rounded-lg"
                    />
                  ) : (
                    employee.employee_id
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  {editingEmployeeId === employee.id ? (
                    <input
                      type="text"
                      value={editingEmployeeData?.fiscal_name || ''}
                      onChange={(e) => handleInputChange('fiscal_name', e.target.value)}
                      className="w-full px-2 py-1 border border-gray-300 rounded-lg"
                    />
                  ) : (
                    employee.fiscal_name
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  {editingEmployeeId === employee.id ? (
                    <select
                      value={editingEmployeeData?.document_type || ''}
                      onChange={(e) => handleInputChange('document_type', e.target.value)}
                      className="w-full px-2 py-1 border border-gray-300 rounded-lg"
                    >
                      <option value="DNI">DNI</option>
                      <option value="NIE">NIE</option>
                      <option value="Pasaporte">Pasaporte</option>
                    </select>
                  ) : (
                    employee.document_type
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  {editingEmployeeId === employee.id ? (
                    <input
                      type="text"
                      value={editingEmployeeData?.document_number || ''}
                      onChange={(e) => handleInputChange('document_number', e.target.value)}
                      className="w-full px-2 py-1 border border-gray-300 rounded-lg"
                    />
                  ) : (
                    employee.document_number
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  {editingEmployeeId === employee.id ? (
                    <input
                      type="email"
                      value={editingEmployeeData?.email || ''}
                      onChange={(e) => handleInputChange('email', e.target.value)}
                      className="w-full px-2 py-1 border border-gray-300 rounded-lg"
                    />
                  ) : (
                    employee.email
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  {editingEmployeeId === employee.id ? (
                    <select
                      multiple
                      value={editingEmployeeData?.work_centers || []}
                      onChange={(e) => {
                        const selectedOptions = Array.from(e.target.selectedOptions, option => option.value);
                        handleInputChange('work_centers', selectedOptions);
                      }}
                      className="w-full px-2 py-1 border border-gray-300 rounded-lg"
                      size={3}
                    >
                      {workCenterOptions.map(center => (
                        <option key={center} value={center}>
                          {center}
                        </option>
                      ))}
                    </select>
                  ) : (
                    employee.work_centers.join(', ')
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  {editingEmployeeId === employee.id ? (
                    <select
                      value={editingEmployeeData?.delegation || ''}
                      onChange={(e) => handleInputChange('delegation', e.target.value)}
                      className="w-full px-2 py-1 border border-gray-300 rounded-lg"
                    >
                      {delegationOptions.map(delegation => (
                        <option key={delegation} value={delegation}>
                          {delegation}
                        </option>
                      ))}
                    </select>
                  ) : (
                    employee.delegation
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  {editingEmployeeId === employee.id ? (
                    <input
                      type="text"
                      value={editingEmployeeData?.pin || ''}
                      onChange={(e) => handleInputChange('pin', e.target.value)}
                      className="w-full px-2 py-1 border border-gray-300 rounded-lg"
                    />
                  ) : (
                    employee.pin
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  {new Date(employee.created_at).toLocaleDateString()}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  {editingEmployeeId === employee.id ? (
                    <input
                      type="date"
                      value={editingEmployeeData?.seniority_date || ''}
                      onChange={(e) => handleInputChange('seniority_date', e.target.value)}
                      className="w-full px-2 py-1 border border-gray-300 rounded-lg"
                    />
                  ) : (
                    employee.seniority_date ? new Date(employee.seniority_date).toLocaleDateString() : ''
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  {editingEmployeeId === employee.id ? (
                    <select
                      multiple
                      value={editingEmployeeData?.job_positions || []}
                      onChange={(e) => {
                        const selectedOptions = Array.from(e.target.selectedOptions, option => option.value);
                        handleInputChange('job_positions', selectedOptions);
                      }}
                      className="w-full px-2 py-1 border border-gray-300 rounded-lg"
                      size={3}
                    >
                      {jobPositions.map(position => (
                        <option key={position} value={position}>
                          {position}
                        </option>
                      ))}
                    </select>
                  ) : (
                    employee.job_positions ? employee.job_positions.join(', ') : ''
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium ${
                    employee.is_active 
                      ? 'bg-green-100 text-green-800' 
                      : 'bg-red-100 text-red-800'
                  }`}>
                    {employee.is_active ? (
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
                <td className="px-6 py-4 whitespace-nowrap">
                  {editingEmployeeId === employee.id ? (
                    <div className="flex gap-2">
                      <button
                        onClick={handleSaveClick}
                        className="p-1 text-green-600 hover:text-green-800"
                      >
                        <Save className="w-5 h-5" />
                      </button>
                      <button
                        onClick={handleCancelClick}
                        className="p-1 text-red-600 hover:text-red-800"
                      >
                        <X className="w-5 h-5" />
                      </button>
                    </div>
                  ) : (
                    <button
                      onClick={() => handleEditClick(employee)}
                      className="p-1 text-blue-600 hover:text-blue-800"
                    >
                      <Edit className="w-5 h-5" />
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        {totalPages > 1 && (
          <div className="px-6 py-4 bg-gray-50 border-t border-gray-200">
            <div className="flex items-center justify-between">
              <button
                onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                disabled={currentPage === 1}
                className="px-4 py-2 border border-gray-300 rounded-lg disabled:opacity-50"
              >
                Anterior
              </button>
              <span className="text-sm text-gray-700">
                Página {currentPage} de {totalPages}
              </span>
              <button
                onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                disabled={currentPage === totalPages}
                className="px-4 py-2 border border-gray-300 rounded-lg disabled:opacity-50"
              >
                Siguiente
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}