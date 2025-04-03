import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { UserPlus, Search, Download, Upload, Check, X, Edit, Save } from 'lucide-react';
import * as XLSX from 'xlsx';

// Interfaces para los tipos de datos
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
}

interface NewEmployee {
  fiscal_name: string;
  email: string;
  document_type: string;
  document_number: string;
  work_centers: string[];
  delegation: string;
  employee_id: string;
  seniority_date: string;
  job_positions: string[];
  selectedWorkCenter?: string;
}

// Opciones para los centros de trabajo
const workCenterOptions = [
  'MADRID HOGARES DE EMANCIPACION V. DEL PARDILLO',
  'MADRID CUEVAS DE ALMANZORA',
  'MADRID OFICINA',
  'MADRID ALCOBENDAS',
  'MADRID JOSE DE PASAMONTE',
  'MADRID VALDEBERNARDO',
  'MADRID MIGUEL HERNANDEZ',
  'MADRID GABRIEL USERA',
  'MADRID IBIZA',
  'MADRID INTERVENCION EDUCATIVA',
  'MADRID HUMANITARIAS',
  'MADRID VIRGEN DEL PUIG',
  'MADRID ALMACEN',
  'MADRID PASEO EXTREMADURA',
  'MADRID HOGARES DE EMANCIPACION SANTA CLARA',
  'MADRID ARROYO DE LAS PILILLAS',
  'MADRID AVDA. DE AMERICA',
  'MADRID CENTRO DE DIA CARMEN HERRERO',
  'MADRID HOGARES DE EMANCIPACION BOCANGEL'
];

// Opciones para los puestos de trabajo
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

// Opciones para las delegaciones
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

export default function SupervisorEmployees() {
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [selectedEmployees, setSelectedEmployees] = useState<string[]>([]);
  const [showActive, setShowActive] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [isAdding, setIsAdding] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [supervisorWorkCenters, setSupervisorWorkCenters] = useState<string[]>([]);
  const [newEmployee, setNewEmployee] = useState<NewEmployee>({
    fiscal_name: '',
    email: '',
    document_type: 'DNI',
    document_number: '',
    work_centers: [],
    delegation: 'MADRID',
    employee_id: '',
    seniority_date: '',
    job_positions: [],
    selectedWorkCenter: ''
  });
  const [editingEmployeeId, setEditingEmployeeId] = useState<string | null>(null);
  const [editingEmployeeData, setEditingEmployeeData] = useState<Employee | null>(null);

  const employeesPerPage = 25;
  const supervisorEmail = localStorage.getItem('supervisorEmail');

  // Función para obtener empleados
  const fetchEmployees = async () => {
    try {
      setLoading(true);
      setError(null);

      // Verificar que supervisorWorkCenters tenga valores
      if (supervisorWorkCenters.length === 0) {
        throw new Error('No se han cargado los centros de trabajo del supervisor');
      }

      // Obtener empleados filtrados por centros de trabajo y estado (activo/inactivo)
      const { data: employeesData, error: employeesError } = await supabase
        .from('employee_profiles')
        .select('*')
        .overlaps('work_centers', supervisorWorkCenters)
        .eq('is_active', showActive)
        .order('fiscal_name', { ascending: true });

      if (employeesError) throw employeesError;

      setEmployees(employeesData || []);
    } catch (err) {
      console.error('Error obteniendo empleados:', err);
      setError(err instanceof Error ? err.message : 'Error al cargar los datos');
    } finally {
      setLoading(false);
    }
  };

  // Obtener los centros de trabajo del supervisor
  useEffect(() => {
    const getSupervisorInfo = async () => {
      try {
        setLoading(true);
        setError(null);

        if (!supervisorEmail) {
          throw new Error('No se encontró el correo electrónico del supervisor');
        }

        const { data: supervisor, error: supervisorError } = await supabase
          .from('supervisor_profiles')
          .select('work_centers')
          .eq('email', supervisorEmail)
          .single();

        if (supervisorError) throw supervisorError;

        if (!supervisor?.work_centers?.length) {
          throw new Error('No se encontraron centros de trabajo asignados');
        }

        setSupervisorWorkCenters(supervisor.work_centers);

        if (supervisor.work_centers.length === 1) {
          setNewEmployee((prev) => ({
            ...prev,
            work_centers: supervisor.work_centers,
            selectedWorkCenter: supervisor.work_centers[0]
          }));
        }
      } catch (err) {
        console.error('Error obteniendo la información del supervisor:', err);
        setError(err instanceof Error ? err.message : 'Error al cargar los datos');
      } finally {
        setLoading(false);
      }
    };

    getSupervisorInfo();
  }, [supervisorEmail]);

  // Cargar empleados cuando supervisorWorkCenters cambie
  useEffect(() => {
    if (supervisorWorkCenters.length > 0) {
      fetchEmployees();
    }
  }, [supervisorWorkCenters, showActive]);

  // Función para manejar el clic en el botón de editar
  const handleEditClick = (employee: Employee) => {
    setEditingEmployeeId(employee.id);
    setEditingEmployeeData({ ...employee });
  };

  // Función para guardar los cambios de un empleado editado
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

      // Recargar la lista de empleados después de guardar
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

  // Función para cancelar la edición
  const handleCancelClick = () => {
    setEditingEmployeeId(null);
    setEditingEmployeeData(null);
  };

  // Función para manejar cambios en los campos de edición
  const handleInputChange = (field: keyof Employee, value: string | string[]) => {
    if (editingEmployeeData) {
      setEditingEmployeeData({ ...editingEmployeeData, [field]: value });
    }
  };

  const handleAddEmployee = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const workCenters = supervisorWorkCenters.length === 1
        ? supervisorWorkCenters
        : [newEmployee.selectedWorkCenter || ''];

      const { error: insertError } = await supabase
        .from('employee_profiles')
        .insert([{
          ...newEmployee,
          work_centers: workCenters,
          is_active: true
        }]);

      if (insertError) throw insertError;

      const { data: employeesData, error: employeesError } = await supabase
        .from('employee_profiles')
        .select('*')
        .overlaps('work_centers', supervisorWorkCenters)
        .eq('is_active', showActive)
        .order('fiscal_name', { ascending: true });

      if (employeesError) throw employeesError;

      setEmployees(employeesData || []);
      setIsAdding(false);
      setNewEmployee({
        fiscal_name: '',
        email: '',
        document_type: 'DNI',
        document_number: '',
        work_centers: [],
        delegation: 'MADRID',
        employee_id: '',
        seniority_date: '',
        job_positions: [],
        selectedWorkCenter: ''
      });
    } catch (err) {
      console.error('Error añadiendo empleado:', err);
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

      if (updateError) throw updateError;

      const { data: employeesData, error: employeesError } = await supabase
        .from('employee_profiles')
        .select('*')
        .overlaps('work_centers', supervisorWorkCenters)
        .eq('is_active', true)
        .order('fiscal_name', { ascending: true });

      if (employeesError) throw employeesError;

      setEmployees(employeesData || []);
      setSelectedEmployees([]);
      setShowActive(false);
    } catch (err) {
      console.error('Error desactivando empleados:', err);
      setError('Error al desactivar empleados');
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

      if (updateError) throw updateError;

      const { data: employeesData, error: employeesError } = await supabase
        .from('employee_profiles')
        .select('*')
        .overlaps('work_centers', supervisorWorkCenters)
        .eq('is_active', false)
        .order('fiscal_name', { ascending: true });

      if (employeesError) throw employeesError;

      setEmployees(employeesData || []);
      setSelectedEmployees([]);
    } catch (err) {
      console.error('Error reactivando empleados:', err);
      setError('Error al reactivar empleados');
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
      const reader = new FileReader();
      reader.onload = async (e) => {
        const text = e.target?.result as string;
        const rows = text.split('\n').slice(1);

        for (const row of rows) {
          try {
            const [
              employee_id,
              fiscal_name,
              document_type,
              document_number,
              email,
              work_centers_str,
              delegation,
              _created_at,
              seniority_date,
              _is_active,
              job_positions_str
            ] = row.split(',').map(field => field.trim().replace(/^"|"$/g, ''));

            if (!fiscal_name || !email) continue;

            const work_centers = work_centers_str ? work_centers_str.split(';').map(wc => wc.trim()) : [];
            const updatedWorkCenters = [...work_centers, ...supervisorWorkCenters];

            const job_positions = job_positions_str ? job_positions_str.split(';').map(jp => jp.trim()) : [];

            const { error: insertError } = await supabase
              .from('employee_profiles')
              .insert([{
                employee_id: employee_id || '',
                fiscal_name,
                email: email.toLowerCase(),
                document_type: document_type || 'DNI',
                document_number: document_number || '',
                work_centers: updatedWorkCenters,
                delegation: delegation || 'MADRID',
                seniority_date: seniority_date || null,
                job_positions,
                is_active: true
              }]);

            if (insertError) {
              console.error('Error importando empleado:', insertError);
              continue;
            }
          } catch (err) {
            console.error('Error procesando fila:', err);
            continue;
          }
        }

        const { data: employeesData, error: employeesError } = await supabase
          .from('employee_profiles')
          .select('*')
          .contains('work_centers', supervisorWorkCenters)
          .eq('is_active', showActive)
          .order('fiscal_name', { ascending: true });

        if (employeesError) throw employeesError;

        setEmployees(employeesData || []);
      };
      reader.readAsText(file);
    } catch (err) {
      console.error('Error importando empleados:', err);
      setError('Error al importar empleados');
    }
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
            onClick={() => setIsAdding(true)}
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
              <X className="w-5 h-5" />
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
            <div className="bg-white rounded-lg p-6 max-w-md w-full">
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-xl font-semibold">Añadir Nuevo Empleado</h2>
                <button
                  onClick={() => setIsAdding(false)}
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

              <form onSubmit={handleAddEmployee} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    ID Empleado
                  </label>
                  <input
                    type="text"
                    value={newEmployee.employee_id}
                    onChange={(e) => setNewEmployee({ ...newEmployee, employee_id: e.target.value })}
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
                    onChange={(e) => setNewEmployee({ ...newEmployee, seniority_date: e.target.value })}
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
                    onChange={(e) => setNewEmployee({ ...newEmployee, fiscal_name: e.target.value })}
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
                    onChange={(e) => setNewEmployee({ ...newEmployee, email: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Tipo de Documento
                  </label>
                  <select
                    value={newEmployee.document_type}
                    onChange={(e) => setNewEmployee({ ...newEmployee, document_type: e.target.value })}
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
                    onChange={(e) => setNewEmployee({ ...newEmployee, document_number: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Delegación
                  </label>
                  <select
                    value={newEmployee.delegation}
                    onChange={(e) => setNewEmployee({ ...newEmployee, delegation: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                  >
                    {delegationOptions.map((delegation) => (
                      <option key={delegation} value={delegation}>
                        {delegation}
                      </option>
                    ))}
                  </select>
                </div>

                {supervisorWorkCenters.length > 1 && (
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Centro de Trabajo
                    </label>
                    <select
                      value={newEmployee.selectedWorkCenter}
                      onChange={(e) => setNewEmployee({ ...newEmployee, selectedWorkCenter: e.target.value })}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      required
                    >
                      <option value="" disabled>Selecciona un centro de trabajo</option>
                      {supervisorWorkCenters.map((workCenter) => (
                        <option key={workCenter} value={workCenter}>
                          {workCenter}
                        </option>
                      ))}
                    </select>
                  </div>
                )}

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Puesto de Trabajo
                  </label>
                  <select
                    multiple
                    value={newEmployee.job_positions}
                    onChange={(e) => {
                      const selectedOptions = Array.from(e.target.selectedOptions, option => option.value);
                      setNewEmployee({ ...newEmployee, job_positions: selectedOptions });
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

                <div className="flex justify-end gap-4 mt-6">
                  <button
                    type="button"
                    onClick={() => setIsAdding(false)}
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
        {/* Contenedor con scroll horizontal */}
        <div className="overflow-x-auto">
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
        </div>

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