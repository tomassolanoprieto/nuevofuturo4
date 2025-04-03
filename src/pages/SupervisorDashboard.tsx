import React, { useState, useEffect } from 'react';
import { useNavigate, Routes, Route } from 'react-router-dom';
import {
  LogOut,
  BarChart,
  Shield,
  User,
  Users,
  Clock,
  Search,
  X,
  Plus,
  Edit,
  Calendar,
  Settings,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import SupervisorEmployees from './SupervisorEmployees';
import SupervisorRequests from './SupervisorRequests';
import SupervisorCalendar from './SupervisorCalendar';
import SupervisorReports from './SupervisorReports';

type TimeEntryType = 'turno' | 'coordinacion' | 'formacion' | 'sustitucion' | 'otros';

const workCenterOptions = [
  "MADRID HOGARES DE EMANCIPACION V. DEL PARDILLO",
  // ... resto de centros de trabajo ...
];

function Overview() {
  const [employees, setEmployees] = useState<any[]>([]);
  const [timeEntries, setTimeEntries] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedEmployee, setSelectedEmployee] = useState<any | null>(null);
  const [showDetailsModal, setShowDetailsModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [editingEntry, setEditingEntry] = useState<any>(null);
  const [newEntry, setNewEntry] = useState({
    timestamp: '',
    entry_type: 'clock_in',
    time_type: 'turno' as TimeEntryType,
    work_center: '',
  });
  const [supervisorWorkCenters, setSupervisorWorkCenters] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);

  const supervisorEmail = localStorage.getItem('supervisorEmail');

  useEffect(() => {
    const getSupervisorInfo = async () => {
      try {
        setLoading(true);
        setError(null);

        if (!supervisorEmail) {
          throw new Error('No se encontró el correo electrónico del supervisor');
        }

        const { data: workCenters, error: workCentersError } = await supabase
          .rpc('get_supervisor_work_centers', {
            p_email: supervisorEmail,
          });

        if (workCentersError) {
          throw workCentersError;
        }

        if (!workCenters?.length) {
          throw new Error('No se encontraron centros de trabajo asignados');
        }

        setSupervisorWorkCenters(workCenters);

        const { data: employeesData, error: employeesError } = await supabase
          .rpc('get_supervisor_center_employees_v6', {
            p_email: supervisorEmail,
          });

        if (employeesError) {
          throw employeesError;
        }

        setEmployees(employeesData || []);
      } catch (err) {
        console.error('Error getting supervisor info:', err);
        setError(err instanceof Error ? err.message : 'Error al cargar los datos');
      } finally {
        setLoading(false);
      }
    };

    getSupervisorInfo();
  }, []);

  useEffect(() => {
    if (employees.length > 0) {
      fetchTimeEntries();
    }
  }, [employees]);

  const fetchTimeEntries = async () => {
    try {
      setError(null);
      const employeeIds = employees.map((emp) => emp.id);

      const { data: timeEntriesData, error } = await supabase
        .from('time_entries')
        .select('*')
        .in('employee_id', employeeIds)
        .eq('is_active', true)
        .order('timestamp', { ascending: false });

      if (error) throw error;
      setTimeEntries(timeEntriesData || []);
    } catch (err) {
      console.error('Error fetching time entries:', err);
      setError(err instanceof Error ? err.message : 'Error al cargar los fichajes');
    }
  };

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

  const employeeWorkTimes = employees.map((employee) => {
    const employeeEntries = timeEntries.filter((entry) => entry.employee_id === employee.id);
    return {
      employee,
      totalTime: calculateEmployeeWorkTime(employeeEntries),
      entries: employeeEntries,
    };
  });

  const handleAddEntry = async () => {
    try {
      const employeeId = selectedEmployee.employee.id;
      const entryDate = new Date(newEntry.timestamp).toISOString().split('T')[0];

      if (newEntry.entry_type !== 'clock_in') {
        const { data: activeEntries, error: fetchError } = await supabase
          .from('time_entries')
          .select('*')
          .eq('employee_id', employeeId)
          .eq('entry_type', 'clock_in')
          .eq('is_active', true)
          .gte('timestamp', `${entryDate}T00:00:00`)
          .lte('timestamp', `${entryDate}T23:59:59`)
          .order('timestamp', { ascending: false })
          .limit(1);

        if (fetchError) throw fetchError;

        if (!activeEntries || activeEntries.length === 0) {
          throw new Error('Debe existir una entrada activa antes de registrar una salida o pausa.');
        }
      }

      if (!workCenterOptions.includes(newEntry.work_center)) {
        throw new Error('El centro de trabajo seleccionado no es válido.');
      }

      const { error } = await supabase.from('time_entries').insert([
        {
          employee_id: employeeId,
          entry_type: newEntry.entry_type,
          time_type: newEntry.entry_type === 'clock_in' ? newEntry.time_type : null,
          timestamp: new Date(newEntry.timestamp).toISOString(),
          changes: null,
          original_timestamp: null,
          is_active: true,
          work_center: newEntry.work_center,
        },
      ]);

      if (error) throw error;

      await fetchTimeEntries();
      setShowEditModal(false);
      setNewEntry({
        timestamp: '',
        entry_type: 'clock_in',
        time_type: 'turno',
        work_center: '',
      });
    } catch (err) {
      console.error('Error adding entry:', err);
      setError(err instanceof Error ? err.message : 'Error al añadir el fichaje');
    }
  };

  const handleUpdateEntry = async () => {
    try {
      const employeeId = selectedEmployee.employee.id;
      const entryDate = new Date(editingEntry.timestamp).toISOString().split('T')[0];

      if (editingEntry.entry_type !== 'clock_in') {
        const { data: activeEntries, error: fetchError } = await supabase
          .from('time_entries')
          .select('*')
          .eq('employee_id', employeeId)
          .eq('entry_type', 'clock_in')
          .eq('is_active', true)
          .gte('timestamp', `${entryDate}T00:00:00`)
          .lte('timestamp', `${entryDate}T23:59:59`)
          .order('timestamp', { ascending: false })
          .limit(1);

        if (fetchError) throw fetchError;

        if (!activeEntries || activeEntries.length === 0) {
          throw new Error('Debe existir una entrada activa antes de registrar una salida o pausa.');
        }
      }

      if (!workCenterOptions.includes(editingEntry.work_center)) {
        throw new Error('El centro de trabajo seleccionado no es válido.');
      }

      const { error } = await supabase
        .from('time_entries')
        .update({
          entry_type: editingEntry.entry_type,
          time_type: editingEntry.entry_type === 'clock_in' ? editingEntry.time_type : null,
          timestamp: new Date(editingEntry.timestamp).toISOString(),
          changes: 'edited',
          original_timestamp: editingEntry.original_timestamp || editingEntry.timestamp,
          work_center: editingEntry.work_center,
        })
        .eq('id', editingEntry.id);

      if (error) throw error;

      await fetchTimeEntries();
      setShowEditModal(false);
      setEditingEntry(null);
    } catch (err) {
      console.error('Error updating entry:', err);
      setError(err instanceof Error ? err.message : 'Error al actualizar el fichaje');
    }
  };

  const handleDeleteEntry = async (entryId: string) => {
    if (!confirm('¿Estás seguro de que quieres eliminar este fichaje?')) return;

    try {
      const { error } = await supabase
        .from('time_entries')
        .update({
          changes: 'eliminated',
          is_active: false,
        })
        .eq('id', entryId);

      if (error) throw error;

      await fetchTimeEntries();
    } catch (err) {
      console.error('Error deleting entry:', err);
      setError('Error al eliminar el fichaje');
    }
  };

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

  const filteredEmployees = employeeWorkTimes.filter(({ employee }) =>
    employee.fiscal_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    employee.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
    (employee.work_centers &&
      employee.work_centers.some(
        (wc: any) => typeof wc === 'string' && wc.toLowerCase().includes(searchTerm.toLowerCase())
      ))
  );

  return (
    <div className="p-8">
      <div className="max-w-7xl mx-auto">
        <div className="mb-8">
          <h1 className="text-2xl font-bold mb-2">Vista General</h1>
          <p className="text-gray-600">Centros de Trabajo: {supervisorWorkCenters.join(', ')}</p>
        </div>

        {error && (
          <div className="mb-6 p-4 bg-red-50 border-l-4 border-red-500 text-red-700">
            {error}
          </div>
        )}

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div className="bg-white p-6 rounded-xl shadow-sm">
            <div className="flex items-center gap-4">
              <Users className="w-8 h-8 text-blue-600" />
              <div>
                <p className="text-sm text-gray-600">Total Empleados</p>
                <p className="text-2xl font-bold">{employees.length}</p>
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
                <p className="text-2xl font-bold">{supervisorWorkCenters.length}</p>
              </div>
            </div>
          </div>
        </div>

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

              <div className="p-6 bg-blue-50 border-b border-blue-200">
                <div className="flex items-center gap-4">
                  <Clock className="w-6 h-6 text-blue-600" />
                  <div>
                    <p className="text-sm text-gray-600">Horas trabajadas hoy</p>
                    <p className="text-xl font-bold">
                      {formatDuration(calculateDailyWorkTime(selectedEmployee.entries))}
                    </p>
                  </div>
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
                    <div className="flex justify-between items-center mb-4">
                      <h3 className="text-lg font-medium">Registro de Fichajes</h3>
                      <button
                        onClick={() => setShowEditModal(true)}
                        className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                      >
                        <Plus className="w-4 h-4" />
                        Añadir Fichaje
                      </button>
                    </div>
                    <div className="bg-gray-50 rounded-lg overflow-hidden">
                      <div className="overflow-x-auto">
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
                              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Acciones
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
                                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                                    <div className="flex gap-2">
                                      <button
                                        onClick={(e) => {
                                          e.stopPropagation();
                                          setEditingEntry({
                                            id: entry.id,
                                            timestamp: new Date(entry.timestamp).toISOString().slice(0, 16),
                                            entry_type: entry.entry_type,
                                            time_type: entry.time_type,
                                            work_center: entry.work_center,
                                            original_timestamp: entry.original_timestamp,
                                          });
                                          setShowEditModal(true);
                                        }}
                                        className="p-1 text-blue-600 hover:text-blue-800"
                                      >
                                        <Edit className="w-4 h-4" />
                                      </button>
                                      <button
                                        onClick={(e) => {
                                          e.stopPropagation();
                                          handleDeleteEntry(entry.id);
                                        }}
                                        className="p-1 text-red-600 hover:text-red-800"
                                      >
                                        <X className="w-4 h-4" />
                                      </button>
                                    </div>
                                  </td>
                                </tr>
                              ))}
                          </tbody>
                        </table>
                      </div>
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

        {/* Modal de Edición/Añadir */}
        {showEditModal && selectedEmployee && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-xl shadow-lg max-w-2xl w-full">
              <div className="p-6 border-b border-gray-200">
                <div className="flex justify-between items-center">
                  <h2 className="text-xl font-semibold">
                    {editingEntry ? 'Editar Fichaje' : 'Añadir Fichaje'}
                  </h2>
                  <button
                    onClick={() => {
                      setShowEditModal(false);
                      setEditingEntry(null);
                      setNewEntry({
                        timestamp: '',
                        entry_type: 'clock_in',
                        time_type: 'turno',
                        work_center: '',
                      });
                    }}
                    className="text-gray-500 hover:text-gray-700"
                  >
                    <X className="w-6 h-6" />
                  </button>
                </div>
              </div>
              <div className="p-6">
                <form
                  onSubmit={(e) => {
                    e.preventDefault();
                    if (editingEntry) {
                      handleUpdateEntry();
                    } else {
                      handleAddEntry();
                    }
                  }}
                  className="space-y-4"
                >
                  {/* Campo: Fecha y Hora */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Fecha y Hora
                    </label>
                    <input
                      type="datetime-local"
                      value={editingEntry ? editingEntry.timestamp : newEntry.timestamp}
                      onChange={(e) => {
                        if (editingEntry) {
                          setEditingEntry({ ...editingEntry, timestamp: e.target.value });
                        } else {
                          setNewEntry({ ...newEntry, timestamp: e.target.value });
                        }
                      }}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      required
                    />
                  </div>

                  {/* Campo: Tipo de Fichaje */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Tipo de Fichaje
                    </label>
                    <select
                      value={editingEntry ? editingEntry.entry_type : newEntry.entry_type}
                      onChange={(e) => {
                        if (editingEntry) {
                          setEditingEntry({ ...editingEntry, entry_type: e.target.value });
                        } else {
                          setNewEntry({ ...newEntry, entry_type: e.target.value });
                        }
                      }}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      required
                    >
                      <option value="clock_in">Entrada</option>
                      <option value="break_start">Inicio Pausa</option>
                      <option value="break_end">Fin Pausa</option>
                      <option value="clock_out">Salida</option>
                    </select>
                  </div>

                  {/* Campo: Tipo de Entrada (solo para ENTRADA) */}
                  {(editingEntry?.entry_type === 'clock_in' || newEntry.entry_type === 'clock_in') && (
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Tipo de Entrada
                      </label>
                      <select
                        value={editingEntry ? editingEntry.time_type : newEntry.time_type}
                        onChange={(e) => {
                          if (editingEntry) {
                            setEditingEntry({
                              ...editingEntry,
                              time_type: e.target.value as TimeEntryType,
                            });
                          } else {
                            setNewEntry({
                              ...newEntry,
                              time_type: e.target.value as TimeEntryType,
                            });
                          }
                        }}
                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                        required
                      >
                        <option value="turno">Fichaje de turno</option>
                        <option value="coordinacion">Fichaje de coordinación</option>
                        <option value="formacion">Fichaje de formación</option>
                        <option value="sustitucion">Fichaje de horas de sustitución</option>
                        <option value="otros">Otros</option>
                      </select>
                    </div>
                  )}

                  {/* Campo: Centro de Trabajo (siempre visible) */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Centro de Trabajo
                    </label>
                    <select
                      value={editingEntry ? editingEntry.work_center : newEntry.work_center}
                      onChange={(e) => {
                        if (editingEntry) {
                          setEditingEntry({ ...editingEntry, work_center: e.target.value });
                        } else {
                          setNewEntry({ ...newEntry, work_center: e.target.value });
                        }
                      }}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      required
                    >
                      <option value="">Selecciona un centro de trabajo</option>
                      {workCenterOptions.map((center) => (
                        <option key={center} value={center}>
                          {center}
                        </option>
                      ))}
                    </select>
                  </div>

                  {/* Botones del Formulario */}
                  <div className="flex justify-end gap-4 mt-6">
                    <button
                      type="button"
                      onClick={() => {
                        setShowEditModal(false);
                        setEditingEntry(null);
                        setNewEntry({
                          timestamp: '',
                          entry_type: 'clock_in',
                          time_type: 'turno',
                          work_center: '',
                        });
                      }}
                      className="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
                    >
                      Cancelar
                    </button>
                    <button
                      type="submit"
                      className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                    >
                      {editingEntry ? 'Guardar Cambios' : 'Añadir Fichaje'}
                    </button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default function SupervisorDashboard() {
  const [activeTab, setActiveTab] = useState('overview');
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center space-x-8">
              <div className="flex items-center">
                <Shield className="h-8 w-8 text-purple-600 mr-2" />
                <span className="text-xl font-bold text-gray-900">Portal Supervisor Centro</span>
              </div>
              <button
                onClick={() => {
                  setActiveTab('overview');
                  navigate('/supervisor/centro');
                }}
                className={`text-gray-900 hover:text-gray-700 px-3 py-2 font-medium ${
                  activeTab === 'overview' ? 'text-purple-600' : ''
                }`}
              >
                Vista General
              </button>
              <button
                onClick={() => {
                  setActiveTab('employees');
                  navigate('/supervisor/centro/empleados');
                }}
                className={`text-gray-900 hover:text-gray-700 px-3 py-2 font-medium ${
                  activeTab === 'employees' ? 'text-purple-600' : ''
                }`}
              >
                Empleados
              </button>
              <button
                onClick={() => {
                  setActiveTab('requests');
                  navigate('/supervisor/centro/solicitudes');
                }}
                className={`text-gray-900 hover:text-gray-700 px-3 py-2 font-medium ${
                  activeTab === 'requests' ? 'text-purple-600' : ''
                }`}
              >
                Solicitudes
              </button>
              <button
                onClick={() => {
                  setActiveTab('reports');
                  navigate('/supervisor/centro/informes');
                }}
                className={`text-gray-900 hover:text-gray-700 px-3 py-2 font-medium ${
                  activeTab === 'reports' ? 'text-purple-600' : ''
                }`}
              >
                Informes
              </button>
              <button
                onClick={() => {
                  setActiveTab('calendar');
                  navigate('/supervisor/centro/calendario');
                }}
                className={`text-gray-900 hover:text-gray-700 px-3 py-2 font-medium ${
                  activeTab === 'calendar' ? 'text-purple-600' : ''
                }`}
              >
                Calendario
              </button>
            </div>
            <div className="flex items-center space-x-4">
              <button
                onClick={() => navigate('/login/supervisor/centro')}
                className="flex items-center text-gray-700 hover:text-gray-900 bg-gray-100 hover:bg-gray-200 px-4 py-2 rounded-lg transition-colors duration-200"
              >
                <LogOut className="h-5 w-5 mr-2" />
                Cerrar sesión
              </button>
            </div>
          </div>
        </div>
      </nav>

      <Routes>
        <Route path="/" element={<Overview />} />
        <Route path="/empleados" element={<SupervisorEmployees />} />
        <Route path="/solicitudes" element={<SupervisorRequests />} />
        <Route path="/informes" element={<SupervisorReports />} />
        <Route path="/calendario" element={<SupervisorCalendar />} />
      </Routes>
    </div>
  );
}