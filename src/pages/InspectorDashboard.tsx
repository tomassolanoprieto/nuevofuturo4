import React, { useState } from 'react';
import { useNavigate, Routes, Route } from 'react-router-dom';
import { LogOut, BarChart, FileText, Shield, Clock, Search, X, Users } from 'lucide-react';
import { useCompany } from '../context/CompanyContext';
import { supabase } from '../lib/supabase';
import CompanyReports from './CompanyReports';

type TimeEntryType = 'turno' | 'coordinacion' | 'formacion' | 'sustitucion' | 'otros';

function Overview() {
  const { employees, timeEntries, loading } = useCompany();
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedEmployee, setSelectedEmployee] = useState<any>(null);
  const [showDetailsModal, setShowDetailsModal] = useState(false);

  console.log('Employees in Overview:', employees);
  console.log('Time Entries in Overview:', timeEntries);

  // Función para formatear la duración
  const formatDuration = (ms: number) => {
    const totalHours = ms / (1000 * 60 * 60);
    const hours = Math.floor(totalHours);
    const minutes = Math.round((totalHours % 1) * 60);
    return `${hours}h ${minutes.toString().padStart(2, '0')}m`;
  };

  const calculateDailyWorkTime = (entries: any[]) => {
    const sortedEntries = [...entries].sort(
      (a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()
    );

    let totalTime = 0;
    let currentShift: { start: any; end: any | null; breaks: any[] } | null = null;
    const completedShifts: { start: any; end: any; breaks: any[] }[] = [];

    for (const entry of sortedEntries) {
      const entryTime = new Date(entry.timestamp);

      switch (entry.entry_type) {
        case 'clock_in':
          if (currentShift) {
            const endOfDay = new Date(currentShift.start.timestamp);
            endOfDay.setHours(23, 59, 59, 999);
            completedShifts.push({
              start: currentShift.start,
              end: { ...currentShift.start, timestamp: endOfDay.toISOString() },
              breaks: currentShift.breaks
            });
          }
          currentShift = {
            start: entry,
            end: null,
            breaks: []
          };
          break;

        case 'break_start':
          if (currentShift && !currentShift.breaks.some(b => !b.end)) {
            currentShift.breaks.push({ start: entry, end: null });
          }
          break;

        case 'break_end':
          if (currentShift?.breaks?.length > 0) {
            const lastBreak = currentShift.breaks[currentShift.breaks.length - 1];
            if (!lastBreak.end) {
              lastBreak.end = entry;
            }
          }
          break;

        case 'clock_out':
          if (currentShift) {
            currentShift.end = entry;
            completedShifts.push({ ...currentShift });
            currentShift = null;
          }
          break;
      }
    }

    if (currentShift) {
      const now = new Date();
      completedShifts.push({
        start: currentShift.start,
        end: { ...currentShift.start, timestamp: now.toISOString() },
        breaks: currentShift.breaks
      });
    }

    for (const shift of completedShifts) {
      const startTime = new Date(shift.start.timestamp);
      const endTime = new Date(shift.end.timestamp);

      let shiftTime = 0;
      if (startTime.toDateString() === endTime.toDateString()) {
        shiftTime = endTime.getTime() - startTime.getTime();
      } else {
        const endOfFirstDay = new Date(startTime);
        endOfFirstDay.setHours(23, 59, 59, 999);
        shiftTime += endOfFirstDay.getTime() - startTime.getTime();
        
        const startOfLastDay = new Date(endTime);
        startOfLastDay.setHours(0, 0, 0, 0);
        shiftTime += endTime.getTime() - startOfLastDay.getTime();
      }

      for (const brk of shift.breaks) {
        if (brk.start && brk.end) {
          const breakStart = new Date(brk.start.timestamp);
          const breakEnd = new Date(brk.end.timestamp);
          shiftTime -= breakEnd.getTime() - breakStart.getTime();
        }
      }

      totalTime += Math.max(0, shiftTime);
    }

    return totalTime;
  };

  const calculateEmployeeWorkTime = (employeeEntries: any[]) => {
    const entriesByDate = employeeEntries.reduce((acc: any, entry) => {
      const date = new Date(entry.timestamp).toISOString().split('T')[0];
      if (!acc[date]) acc[date] = [];
      acc[date].push(entry);
      return acc;
    }, {});

    let totalTime = 0;
    Object.values(entriesByDate).forEach((dayEntries: any) => {
      totalTime += calculateDailyWorkTime(dayEntries);
    });
    return totalTime;
  };

  const employeeWorkTimes = React.useMemo(() => {
    if (!employees || !timeEntries) return [];

    return employees.map((employee) => {
      const employeeEntries = timeEntries.filter((entry) => entry.employee_id === employee.id && entry.is_active);
      return {
        employee,
        totalTime: calculateEmployeeWorkTime(employeeEntries),
        entries: employeeEntries,
      };
    });
  }, [employees, timeEntries]);

  const getEntryTypeText = (type: string) => {
    switch (type) {
      case 'clock_in':
        return 'Entrada';
      case 'break_start':
        return 'Inicio Pausa';
      case 'break_end':
        return 'Fin Pausa';
      case 'clock_out':
        return 'Salida';
      default:
        return type;
    }
  };

  const getTimeTypeText = (type: TimeEntryType | null) => {
    switch (type) {
      case 'turno':
        return 'Fichaje de turno';
      case 'coordinacion':
        return 'Fichaje de coordinación';
      case 'formacion':
        return 'Fichaje de formación';
      case 'sustitucion':
        return 'Fichaje de horas de sustitución';
      case 'otros':
        return 'Otros';
      default:
        return '';
    }
  };

  const totalWorkTime = employeeWorkTimes.reduce((acc, curr) => acc + curr.totalTime, 0);

  // Filtrar empleados basados en el término de búsqueda
  const filteredEmployees = React.useMemo(() => {
    if (!employeeWorkTimes) return [];

    return employeeWorkTimes.filter(({ employee }) =>
      employee.fiscal_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      employee.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (employee.work_centers &&
        employee.work_centers.some(
          (wc: any) => typeof wc === 'string' && wc.toLowerCase().includes(searchTerm.toLowerCase())
        ))
    );
  }, [employeeWorkTimes, searchTerm]);

  return (
    <div className="p-8">
      <div className="max-w-7xl mx-auto">
        <div className="mb-8">
          <h1 className="text-2xl font-bold mb-2">Vista General</h1>
          <p className="text-gray-600">Visualiza los horarios de trabajo de forma precisa y eficiente</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div className="bg-white p-6 rounded-xl shadow-sm">
            <div className="flex items-center gap-4">
              <Users className="w-8 h-8 text-blue-600" />
              <div>
                <p className="text-sm text-gray-600">Total Empleados</p>
                <p className="text-2xl font-bold">{employees?.length || 0}</p>
              </div>
            </div>
          </div>
          <div className="bg-white p-6 rounded-xl shadow-sm">
            <div className="flex items-center gap-4">
              <Clock className="w-8 h-8 text-green-600" />
              <div>
                <p className="text-sm text-gray-600">Tiempo Total Trabajado</p>
                <p className="text-2xl font-bold">{formatDuration(totalWorkTime)}</p>
              </div>
            </div>
          </div>
          <div className="bg-white p-6 rounded-xl shadow-sm">
            <div className="flex items-center gap-4">
              <Shield className="w-8 h-8 text-purple-600" />
              <div>
                <p className="text-sm text-gray-600">Centros de Trabajo</p>
                <p className="text-2xl font-bold">
                  {new Set(employees?.flatMap((emp) => emp.work_centers || [])).size || 0}
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Buscador */}
        <div className="mb-6">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Buscar empleados..."
            />
          </div>
        </div>

        {/* Lista de Empleados */}
        <div className="bg-white rounded-xl shadow-sm overflow-hidden">
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
                  Tiempo Trabajado
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {loading ? (
                <tr>
                  <td colSpan={4} className="px-6 py-4 text-center">
                    Cargando...
                  </td>
                </tr>
              ) : filteredEmployees.length === 0 ? (
                <tr>
                  <td colSpan={4} className="px-6 py-4 text-center">
                    No hay empleados para mostrar
                  </td>
                </tr>
              ) : (
                filteredEmployees.map(({ employee, totalTime, entries }) => (
                  <tr
                    key={employee.id}
                    className="hover:bg-gray-50 cursor-pointer"
                    onClick={() => {
                      setSelectedEmployee({ employee, totalTime, entries });
                      setShowDetailsModal(true);
                    }}
                  >
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-gray-900">
                        {employee.fiscal_name}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-500">
                        {employee.email}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-500">
                        {Array.isArray(employee.work_centers) ? employee.work_centers.join(', ') : ''}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="text-sm font-medium text-gray-900">
                        {formatDuration(totalTime)}
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Modal de Detalles */}
        {showDetailsModal && selectedEmployee && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-xl shadow-lg max-w-6xl w-full max-h-[80vh] overflow-hidden">
              <div className="p-6 border-b border-gray-200">
                <div className="flex justify-between items-center">
                  <h2 className="text-xl font-semibold">
                    Detalles de Fichajes - {selectedEmployee.employee.fiscal_name}
                  </h2>
                  <button
                    onClick={() => setShowDetailsModal(false)}
                    className="text-gray-500 hover:text-gray-700"
                  >
                    <X className="w-6 h-6" />
                  </button>
                </div>
              </div>

              <div className="p-6 overflow-y-auto" style={{ maxHeight: '60vh' }}>
                <div className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <p className="text-sm text-gray-500">Email</p>
                      <p className="font-medium">{selectedEmployee.employee.email}</p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-500">Centros de Trabajo</p>
                      <p className="font-medium">
                        {Array.isArray(selectedEmployee.employee.work_centers)
                          ? selectedEmployee.employee.work_centers.join(', ')
                          : ''}
                      </p>
                    </div>
                  </div>

                  <div className="mt-6">
                    <h3 className="text-lg font-medium">Registro de Fichajes</h3>
                    <div className="bg-gray-50 rounded-lg overflow-hidden">
                      <table className="min-w-full divide-y divide-gray-200">
                        <thead>
                          <tr>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                              Fecha
                            </th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                              Hora
                            </th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                              Tipo
                            </th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                              Tipo de Fichaje
                            </th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                              Centro de Trabajo
                            </th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                              Cambios
                            </th>
                          </tr>
                        </thead>
                        <tbody className="bg-white divide-y divide-gray-200">
                          {selectedEmployee.entries
                            .sort(
                              (a: any, b: any) =>
                                new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
                            )
                            .map((entry: any) => (
                              <tr key={entry.id} className="hover:bg-gray-50">
                                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                                  {new Date(entry.timestamp).toLocaleDateString()}
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                                  {new Date(entry.timestamp).toLocaleTimeString()}
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                                  {getEntryTypeText(entry.entry_type)}
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                                  {entry.entry_type === 'clock_in' ? getTimeTypeText(entry.time_type) : ''}
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                                  {entry.work_center || ''}
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                                  {entry.changes || 'N/A'}
                                </td>
                              </tr>
                            ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>
              </div>
              <div className="p-6 border-t border-gray-200">
                <div className="flex justify-end">
                  <button
                    onClick={() => setShowDetailsModal(false)}
                    className="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                  >
                    Cerrar
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default function InspectorDashboard() {
  const [activeTab, setActiveTab] = useState('overview');
  const navigate = useNavigate();

  const handleLogout = async () => {
    await supabase.auth.signOut();
    navigate('/login/inspector');
  };

  return (
    <div className="min-h-screen bg-gray-50 flex">
      {/* Sidebar */}
      <div className="w-64 bg-white shadow-lg">
        <div className="p-6">
          <div className="flex items-center gap-2 mb-8">
            <Shield className="w-8 h-8 text-blue-600" />
            <span className="text-xl font-bold">Portal Inspector</span>
          </div>
          <nav className="space-y-2">
            <button
              onClick={() => {
                setActiveTab('overview');
                navigate('/inspector');
              }}
              className={`w-full flex items-center gap-2 px-4 py-2 rounded-lg ${
                activeTab === 'overview' ? 'bg-blue-50 text-blue-600' : 'text-gray-600 hover:bg-gray-50'
              }`}
            >
              <BarChart className="w-5 h-5" />
              Vista General
            </button>
            <button
              onClick={() => {
                setActiveTab('reports');
                navigate('/inspector/informes');
              }}
              className={`w-full flex items-center gap-2 px-4 py-2 rounded-lg ${
                activeTab === 'reports' ? 'bg-blue-50 text-blue-600' : 'text-gray-600 hover:bg-gray-50'
              }`}
            >
              <FileText className="w-5 h-5" />
              Informes
            </button>
          </nav>
        </div>
        <div className="absolute bottom-0 w-64 p-4">
          <button
            onClick={handleLogout}
            className="w-full flex items-center gap-2 px-4 py-2 text-gray-600 hover:bg-gray-50 rounded-lg"
          >
            <LogOut className="w-5 h-5" />
            Cerrar Sesión
          </button>
        </div>
      </div>

      {/* Main Content */}
      <div className="flex-1">
        <Routes>
          <Route path="/" element={<Overview />} />
          <Route path="/informes" element={<CompanyReports />} />
        </Routes>
      </div>
    </div>
  );
}