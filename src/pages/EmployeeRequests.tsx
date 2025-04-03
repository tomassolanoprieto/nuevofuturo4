import React, { useState, useEffect } from 'react';
import { FileText, Clock } from 'lucide-react';
import { supabase } from '../lib/supabase';

type RequestType = 'fichajes' | 'planificador';
type TimeEntryType = 'clock_in' | 'break_start' | 'break_end' | 'clock_out';
type PlannerType = 'Horas compensadas' | 'Horas vacaciones' | 'Horas asuntos propios';
type TimeType = 'turno' | 'coordinacion' | 'formacion' | 'otros' | 'sustitucion';

interface TimeRequest {
  id: string;
  employee_id: string;
  datetime: string;
  entry_type: TimeEntryType;
  time_type: TimeType | null;
  work_center: string;
  comment: string;
  status: 'pending' | 'approved' | 'rejected';
  created_at: string;
}

interface PlannerRequest {
  id: string;
  employee_id: string;
  planner_type: PlannerType;
  start_date: string;
  end_date: string;
  comment: string;
  status: 'pending' | 'approved' | 'rejected';
  created_at: string;
}

export default function EmployeeRequests() {
  const [activeRequest, setActiveRequest] = useState<RequestType | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  // Time request state
  const [datetime, setDatetime] = useState('');
  const [comment, setComment] = useState('');
  const [entryType, setEntryType] = useState<TimeEntryType>('clock_in');
  const [timeType, setTimeType] = useState<TimeType>('turno');
  const [workCenters, setWorkCenters] = useState<string[]>([]);
  const [selectedWorkCenter, setSelectedWorkCenter] = useState<string>('');
  const [timeRequests, setTimeRequests] = useState<TimeRequest[]>([]);
  
  // Planner request state
  const [plannerType, setPlannerType] = useState<PlannerType>('Horas compensadas');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [plannerComment, setPlannerComment] = useState('');
  const [plannerRequests, setPlannerRequests] = useState<PlannerRequest[]>([]);

  useEffect(() => {
    fetchRequests();
    fetchWorkCenters();
  }, []);

  const fetchWorkCenters = async () => {
    try {
      const employeeId = localStorage.getItem('employeeId');
      if (!employeeId) {
        throw new Error('No se encontró el ID del empleado');
      }

      const { data, error } = await supabase
        .from('employee_profiles')
        .select('work_centers')
        .eq('id', employeeId)
        .single();

      if (error) throw error;

      if (data?.work_centers) {
        setWorkCenters(data.work_centers);
        setSelectedWorkCenter(data.work_centers[0] || '');
      } else {
        console.warn('No se encontraron centros de trabajo para el empleado.');
        setWorkCenters([]);
        setSelectedWorkCenter('');
      }
    } catch (err) {
      console.error('Error fetching work centers:', err);
      setError(err instanceof Error ? err.message : 'Error al cargar los centros de trabajo');
    }
  };

  const fetchRequests = async () => {
    try {
      setLoading(true);
      setError(null);

      const employeeId = localStorage.getItem('employeeId');
      if (!employeeId) {
        throw new Error('No se encontró el ID del empleado');
      }

      const { data: timeData, error: timeError } = await supabase
        .from('time_requests')
        .select('*')
        .eq('employee_id', employeeId)
        .order('created_at', { ascending: false });

      if (timeError) throw timeError;
      setTimeRequests(timeData || []);

      const { data: plannerData, error: plannerError } = await supabase
        .from('planner_requests')
        .select('*')
        .eq('employee_id', employeeId)
        .order('created_at', { ascending: false });

      if (plannerError) throw plannerError;
      setPlannerRequests(plannerData || []);

    } catch (err) {
      console.error('Error fetching requests:', err);
      setError(err instanceof Error ? err.message : 'Error al cargar las solicitudes');
    } finally {
      setLoading(false);
    }
  };

  const handleTimeSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      setLoading(true);
      setError(null);

      const employeeId = localStorage.getItem('employeeId');
      if (!employeeId) {
        throw new Error('No se encontró el ID del empleado');
      }

      const { error: insertError } = await supabase
        .from('time_requests')
        .insert([{
          employee_id: employeeId,
          datetime: new Date(datetime).toISOString(),
          entry_type: entryType,
          time_type: entryType === 'clock_in' ? timeType : null,
          work_center: selectedWorkCenter,
          comment,
          status: 'pending'
        }]);

      if (insertError) throw insertError;

      setDatetime('');
      setComment('');
      setEntryType('clock_in');
      setTimeType('turno');
      await fetchRequests();

    } catch (err) {
      console.error('Error submitting time request:', err);
      setError(err instanceof Error ? err.message : 'Error al enviar la solicitud');
    } finally {
      setLoading(false);
    }
  };

  const handlePlannerSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      setLoading(true);
      setError(null);

      const employeeId = localStorage.getItem('employeeId');
      if (!employeeId) {
        throw new Error('No se encontró el ID del empleado');
      }

      const { error: insertError } = await supabase
        .from('planner_requests')
        .insert([{
          employee_id: employeeId,
          planner_type: plannerType,
          start_date: startDate,
          end_date: endDate,
          comment: plannerComment,
          status: 'pending'
        }]);

      if (insertError) throw insertError;

      setPlannerType('Horas compensadas');
      setStartDate('');
      setEndDate('');
      setPlannerComment('');
      await fetchRequests();

    } catch (err) {
      console.error('Error submitting planner request:', err);
      setError(err instanceof Error ? err.message : 'Error al enviar la solicitud');
    } finally {
      setLoading(false);
    }
  };

  const getEntryTypeText = (type: TimeEntryType) => {
    switch (type) {
      case 'clock_in': return 'Entrada';
      case 'break_start': return 'Pausa';
      case 'break_end': return 'Volver';
      case 'clock_out': return 'Salida';
    }
  };

  const getStatusBadgeClasses = (status: string) => {
    switch (status) {
      case 'approved':
        return 'bg-green-100 text-green-800';
      case 'rejected':
        return 'bg-red-100 text-red-800';
      default:
        return 'bg-yellow-100 text-yellow-800';
    }
  };

  const getStatusText = (status: string) => {
    switch (status) {
      case 'approved':
        return 'Aprobada';
      case 'rejected':
        return 'Rechazada';
      default:
        return 'Pendiente';
    }
  };

  return (
    <div className="max-w-7xl mx-auto px-4 py-8">
      <div className="bg-white rounded-xl shadow-lg p-6">
        <h2 className="text-2xl font-bold mb-6">Solicitudes</h2>
        
        {error && (
          <div className="mb-6 p-4 bg-red-50 border-l-4 border-red-500 text-red-700">
            {error}
          </div>
        )}
        
        <div className="mb-8">
          <h3 className="text-lg font-medium text-gray-700 mb-4">Motivo de la solicitud</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <button 
              onClick={() => setActiveRequest('fichajes')}
              className={`flex items-center justify-center gap-3 px-6 py-4 rounded-lg transition-colors ${
                activeRequest === 'fichajes' 
                  ? 'bg-blue-600 text-white' 
                  : 'bg-white border-2 border-blue-600 text-blue-600 hover:bg-blue-50'
              }`}
            >
              <Clock className="w-5 h-5" />
              <span className="font-medium">Fichajes</span>
            </button>
            <button 
              onClick={() => setActiveRequest('planificador')}
              className={`flex items-center justify-center gap-3 px-6 py-4 rounded-lg transition-colors ${
                activeRequest === 'planificador'
                  ? 'bg-blue-600 text-white'
                  : 'bg-white border-2 border-blue-600 text-blue-600 hover:bg-blue-50'
              }`}
            >
              <FileText className="w-5 h-5" />
              <span className="font-medium">Planificador</span>
            </button>
          </div>
        </div>

        {activeRequest === 'fichajes' && (
          <div className="mb-8">
            <h3 className="text-xl font-semibold mb-6">Solicitud de Fichaje</h3>
            <form onSubmit={handleTimeSubmit} className="space-y-6 max-w-2xl">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Fecha y hora inicio
                </label>
                <input
                  type="datetime-local"
                  value={datetime}
                  onChange={(e) => setDatetime(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Centro de trabajo
                </label>
                <select
                  value={selectedWorkCenter}
                  onChange={(e) => setSelectedWorkCenter(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  required
                >
                  {workCenters.map((center) => (
                    <option key={center} value={center}>
                      {center}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Tipo de fichaje
                </label>
                <select
                  value={entryType}
                  onChange={(e) => setEntryType(e.target.value as TimeEntryType)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  required
                >
                  <option value="clock_in">Entrada</option>
                  <option value="break_start">Pausa</option>
                  <option value="break_end">Volver</option>
                  <option value="clock_out">Salida</option>
                </select>
              </div>

              {entryType === 'clock_in' && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Tipo de fichaje (solo para entrada)
                  </label>
                  <select
                    value={timeType}
                    onChange={(e) => setTimeType(e.target.value as TimeType)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                  >
                    <option value="turno">Fichaje de turno</option>
                    <option value="coordinacion">Fichaje de coordinación</option>
                    <option value="formacion">Fichaje de formación</option>
                    <option value="sustitucion">Fichaje de sustitución</option>
                    <option value="otros">Otros</option>
                  </select>
                </div>
              )}

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Comentario
                </label>
                <textarea
                  value={comment}
                  onChange={(e) => setComment(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  rows={4}
                  required
                />
              </div>

              <button
                type="submit"
                disabled={loading}
                className="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 rounded-lg transition-colors disabled:opacity-50"
              >
                {loading ? 'Enviando...' : 'Enviar Solicitud'}
              </button>
            </form>
          </div>
        )}

        {activeRequest === 'planificador' && (
          <div className="mb-8">
            <h3 className="text-xl font-semibold mb-6">Solicitud de Planificador</h3>
            <form onSubmit={handlePlannerSubmit} className="space-y-6 max-w-2xl">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Tipo de Planificador
                </label>
                <select
                  value={plannerType}
                  onChange={(e) => setPlannerType(e.target.value as PlannerType)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  required
                >
                  <option value="Horas compensadas">Horas compensadas</option>
                  <option value="Horas vacaciones">Horas vacaciones</option>
                  <option value="Horas asuntos propios">Horas asuntos propios</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Fecha inicio
                </label>
                <input
                  type="datetime-local"
                  value={startDate}
                  onChange={(e) => setStartDate(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Fecha fin
                </label>
                <input
                  type="datetime-local"
                  value={endDate}
                  onChange={(e) => setEndDate(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Comentario
                </label>
                <textarea
                  value={plannerComment}
                  onChange={(e) => setPlannerComment(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  rows={4}
                  required
                />
              </div>

              <button
                type="submit"
                disabled={loading}
                className="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 rounded-lg transition-colors disabled:opacity-50"
              >
                {loading ? 'Enviando...' : 'Enviar Solicitud'}
              </button>
            </form>
          </div>
        )}

        <div>
          <h3 className="text-xl font-semibold mb-6">Últimas Peticiones</h3>
          
          {activeRequest === 'fichajes' && (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead>
                  <tr>
                    <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Fecha y Hora
                    </th>
                    <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Tipo
                    </th>
                    <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Tipo de fichaje
                    </th>
                    <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Centro de trabajo
                    </th>
                    <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Estado
                    </th>
                    <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Comentario
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {loading ? (
                    <tr>
                      <td colSpan={6} className="px-6 py-4 text-center">
                        Cargando solicitudes...
                      </td>
                    </tr>
                  ) : timeRequests.length === 0 ? (
                    <tr>
                      <td colSpan={6} className="px-6 py-4 text-center">
                        No hay solicitudes para mostrar
                      </td>
                    </tr>
                  ) : (
                    timeRequests.map((request) => (
                      <tr key={request.id}>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {new Date(request.datetime).toLocaleString('es-ES', {
                            timeZone: 'Europe/Madrid',
                            hour12: false,
                          })}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {getEntryTypeText(request.entry_type)}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {request.time_type || 'N/A'}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {request.work_center || 'N/A'}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusBadgeClasses(request.status)}`}>
                            {getStatusText(request.status)}
                          </span>
                        </td>
                        <td className="px-6 py-4">
                          {request.comment}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          )}

          {activeRequest === 'planificador' && (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead>
                  <tr>
                    <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Tipo
                    </th>
                    <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Fecha Inicio
                    </th>
                    <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Fecha Fin
                    </th>
                    <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Estado
                    </th>
                    <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Comentario
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {loading ? (
                    <tr>
                      <td colSpan={5} className="px-6 py-4 text-center">
                        Cargando solicitudes...
                      </td>
                    </tr>
                  ) : plannerRequests.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="px-6 py-4 text-center">
                        No hay solicitudes para mostrar
                      </td>
                    </tr>
                  ) : (
                    plannerRequests.map((request) => (
                      <tr key={request.id}>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {request.planner_type}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {new Date(request.start_date).toLocaleString('es-ES', {
                            timeZone: 'Europe/Madrid',
                            hour12: false,
                          })}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {new Date(request.end_date).toLocaleString('es-ES', {
                            timeZone: 'Europe/Madrid',
                            hour12: false,
                          })}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusBadgeClasses(request.status)}`}>
                            {getStatusText(request.status)}
                          </span>
                        </td>
                        <td className="px-6 py-4">
                          {request.comment}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}