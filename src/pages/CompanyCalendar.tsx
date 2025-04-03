import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { Calendar, FileText, ChevronLeft, ChevronRight, Plus, X } from 'lucide-react';

interface CalendarEvent {
  title: string;
  start: string;
  end: string;
  color: string;
  type: 'planner' | 'holiday';
  details?: {
    employeeName?: string;
    plannerType?: string;
    hours?: number;
  };
}

interface NewHoliday {
  date: string;
  name: string;
  work_center: string | null;
}

interface NewPlanner {
  employeeId: string;
  plannerType: 'Horas compensadas' | 'Horas vacaciones' | 'Horas asuntos propios';
  startDate: string;
  endDate: string;
  comment: string;
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

export default function CompanyCalendar() {
  const [calendarEvents, setCalendarEvents] = useState<CalendarEvent[]>([]);
  const [currentDate, setCurrentDate] = useState(new Date());
  const [showPlannerRequests, setShowPlannerRequests] = useState(true);
  const [showHolidays, setShowHolidays] = useState(true);
  const [selectedEmployee, setSelectedEmployee] = useState<string | null>(null);
  const [selectedWorkCenter, setSelectedWorkCenter] = useState<string | null>(null);
  const [employees, setEmployees] = useState<any[]>([]);
  const [showHolidayForm, setShowHolidayForm] = useState(false);
  const [showPlannerForm, setShowPlannerForm] = useState(false);
  const [newHoliday, setNewHoliday] = useState<NewHoliday>({
    date: '',
    name: '',
    work_center: null,
  });
  const [newPlanner, setNewPlanner] = useState<NewPlanner>({
    employeeId: '',
    plannerType: 'Horas compensadas',
    startDate: '',
    endDate: '',
    comment: '',
  });

  useEffect(() => {
    fetchEmployees();
  }, [selectedWorkCenter]);

  useEffect(() => {
    if (selectedEmployee || selectedWorkCenter) {
      fetchCalendarEvents();
    } else {
      setCalendarEvents([]);
    }
  }, [selectedEmployee, selectedWorkCenter, currentDate]);

  const fetchEmployees = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      let query = supabase
        .from('employee_profiles')
        .select('*')
        .eq('is_active', true)
        .order('fiscal_name');

      if (selectedWorkCenter) {
        query = query.contains('work_centers', [selectedWorkCenter]);
      }

      const { data, error } = await query;

      if (error) {
        console.error('Error fetching employees:', error);
        return;
      }

      if (data) {
        setEmployees(data);
      }
    } catch (error) {
      console.error('Error fetching employees:', error);
    }
  };

  const fetchCalendarEvents = async () => {
    try {
      const startOfMonth = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1);
      const endOfMonth = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0);

      startOfMonth.setHours(0, 0, 0, 0);
      endOfMonth.setHours(23, 59, 59, 999);

      // Get planner requests
      let query = supabase
        .from('planner_requests')
        .select(`
          *,
          employee_profiles!inner (
            id,
            fiscal_name,
            work_centers
          )
        `)
        .eq('status', 'approved')
        .gte('start_date', startOfMonth.toISOString())
        .lte('end_date', endOfMonth.toISOString());

      if (selectedEmployee) {
        query = query.eq('employee_id', selectedEmployee);
      }

      if (selectedWorkCenter) {
        query = query.contains('employee_profiles.work_centers', [selectedWorkCenter]);
      }

      const [plannerResponse, holidaysResponse] = await Promise.all([
        query,
        supabase
          .from('holidays')
          .select('*')
          .gte('date', startOfMonth.toISOString())
          .lte('date', endOfMonth.toISOString())
          .or(`work_center.is.null,work_center.eq.${selectedWorkCenter}`),
      ]);

      if (plannerResponse.error) {
        console.error('Error fetching planner requests:', plannerResponse.error);
        return;
      }

      if (holidaysResponse.error) {
        console.error('Error fetching holidays:', holidaysResponse.error);
        return;
      }

      const events: CalendarEvent[] = [];

      // Process planner requests
      (plannerResponse.data || []).forEach((p) => {
        const start = new Date(p.start_date);
        const end = new Date(p.end_date);
        let current = new Date(start);

        // Iterar sobre todos los días entre la fecha de inicio y la fecha de fin
        while (current <= end) {
          if (current >= startOfMonth && current <= endOfMonth) {
            events.push({
              title: `${p.employee_profiles.fiscal_name} - ${p.planner_type}`,
              start: current.toISOString(),
              end: current.toISOString(),
              color: '#22c55e',
              type: 'planner',
              details: {
                employeeName: p.employee_profiles.fiscal_name,
                plannerType: p.planner_type,
                hours: 8, // Default 8 hours per day
              },
            });
          }
          current.setDate(current.getDate() + 1); // Avanzar al siguiente día
        }
      });

      // Process holidays
      (holidaysResponse.data || []).forEach((h) => {
        events.push({
          title: h.name + (h.work_center ? ` (${h.work_center})` : ' (Todos los centros)'),
          start: h.date,
          end: h.date,
          color: '#f97316',
          type: 'holiday',
        });
      });

      setCalendarEvents(events);
    } catch (err) {
      console.error('Error fetching calendar events:', err);
    }
  };

  const handleAddHoliday = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('No se encontró el usuario autenticado');

      const { error: insertError } = await supabase
        .from('holidays')
        .insert([{
          date: newHoliday.date,
          name: newHoliday.name,
          type: 'company',
          company_id: user.id,
          work_center: newHoliday.work_center,
        }]);

      if (insertError) throw insertError;

      setShowHolidayForm(false);
      setNewHoliday({ date: '', name: '', work_center: null });
      fetchCalendarEvents();
    } catch (error) {
      console.error('Error adding holiday:', error);
    }
  };

  const handleAddPlanner = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const { error } = await supabase
        .from('planner_requests')
        .insert([{
          employee_id: newPlanner.employeeId,
          planner_type: newPlanner.plannerType,
          start_date: newPlanner.startDate,
          end_date: newPlanner.endDate,
          comment: newPlanner.comment,
          status: 'approved',
        }]);

      if (error) throw error;

      setShowPlannerForm(false);
      setNewPlanner({
        employeeId: '',
        plannerType: 'Horas compensadas',
        startDate: '',
        endDate: '',
        comment: '',
      });
      fetchCalendarEvents();
    } catch (error) {
      console.error('Error adding planner:', error);
    }
  };

  const getDaysInMonth = (date: Date) => {
    const year = date.getFullYear();
    const month = date.getMonth();
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    const days = [];

    // Add empty days for padding
    const firstDayOfWeek = firstDay.getDay();
    for (let i = 0; i < (firstDayOfWeek === 0 ? 6 : firstDayOfWeek - 1); i++) {
      days.push(null);
    }

    // Add actual days
    for (let i = 1; i <= lastDay.getDate(); i++) {
      days.push(new Date(year, month, i));
    }

    return days;
  };

  const navigateMonth = (direction: 'prev' | 'next') => {
    setCurrentDate((date) => {
      const newDate = new Date(date);
      if (direction === 'prev') {
        newDate.setMonth(date.getMonth() - 1);
      } else {
        newDate.setMonth(date.getMonth() + 1);
      }
      return newDate;
    });
  };

  return (
    <div className="p-8">
      <div className="max-w-7xl mx-auto">
        <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
          {/* Sidebar */}
          <div className="lg:col-span-1 space-y-6">
            {/* Work Center Selection */}
            <div className="bg-white p-6 rounded-xl shadow-sm">
              <h2 className="text-lg font-semibold mb-4">Centro de Trabajo</h2>
              <select
                value={selectedWorkCenter || ''}
                onChange={(e) => {
                  setSelectedWorkCenter(e.target.value || null);
                  setSelectedEmployee(null); // Reset employee when work center changes
                }}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="">Todos los centros</option>
                {workCenterOptions.map((center) => (
                  <option key={center} value={center}>
                    {center}
                  </option>
                ))}
              </select>
            </div>

            {/* Employee Selection */}
            <div className="bg-white p-6 rounded-xl shadow-sm">
              <h2 className="text-lg font-semibold mb-4">Empleado</h2>
              <select
                value={selectedEmployee || ''}
                onChange={(e) => {
                  setSelectedEmployee(e.target.value || null);
                }}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="">Todos los empleados</option>
                {employees.map((emp) => (
                  <option key={emp.id} value={emp.id}>
                    {emp.fiscal_name}
                  </option>
                ))}
              </select>
            </div>

            {/* Event Filters */}
            <div className="bg-white p-6 rounded-xl shadow-sm">
              <h2 className="text-lg font-semibold mb-4">Filtros</h2>
              <div className="space-y-4">
                <button
                  onClick={() => setShowPlannerRequests(!showPlannerRequests)}
                  className={`flex items-center gap-2 w-full px-4 py-2 text-green-600 hover:bg-green-50 rounded-lg transition-colors ${
                    showPlannerRequests ? 'bg-green-50' : ''
                  }`}
                >
                  <FileText className="w-5 h-5" />
                  Planificador
                </button>
                <button
                  onClick={() => setShowHolidays(!showHolidays)}
                  className={`flex items-center gap-2 w-full px-4 py-2 text-orange-600 hover:bg-orange-50 rounded-lg transition-colors ${
                    showHolidays ? 'bg-orange-50' : ''
                  }`}
                >
                  <Calendar className="w-5 h-5" />
                  Festivos
                </button>
              </div>
            </div>

            {/* Action Buttons */}
            <div className="bg-white p-6 rounded-xl shadow-sm space-y-4">
              <h2 className="text-lg font-semibold mb-4">Acciones</h2>
              <button
                onClick={() => setShowPlannerForm(true)}
                className="flex items-center gap-2 w-full px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
              >
                <Plus className="w-5 h-5" />
                Añadir Planificador
              </button>
              <button
                onClick={() => setShowHolidayForm(true)}
                className="flex items-center gap-2 w-full px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition-colors"
              >
                <Plus className="w-5 h-5" />
                Añadir Festivo
              </button>
            </div>
          </div>

          {/* Calendar */}
          <div className="lg:col-span-3">
            <div className="bg-white p-6 rounded-xl shadow-sm">
              {/* Month Navigation */}
              <div className="flex items-center justify-between mb-6">
                <button
                  onClick={() => navigateMonth('prev')}
                  className="p-2 hover:bg-gray-100 rounded-lg"
                >
                  <ChevronLeft className="w-5 h-5" />
                </button>
                <h2 className="text-xl font-semibold">
                  {currentDate.toLocaleString('es-ES', { month: 'long', year: 'numeric' })}
                </h2>
                <button
                  onClick={() => navigateMonth('next')}
                  className="p-2 hover:bg-gray-100 rounded-lg"
                >
                  <ChevronRight className="w-5 h-5" />
                </button>
              </div>

              {/* Calendar Grid */}
              <div className="grid grid-cols-7 gap-2">
                {/* Calendar Header */}
                {['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'].map((day) => (
                  <div key={day} className="text-center font-semibold py-2">
                    {day}
                  </div>
                ))}
                {/* Calendar Days */}
                {getDaysInMonth(currentDate).map((date, index) => (
                  <div
                    key={index}
                    className={`min-h-[100px] p-2 border rounded-lg ${
                      date ? 'bg-white' : 'bg-gray-50'
                    }`}
                  >
                    {date && (
                      <>
                        <div className="font-medium mb-1">
                          {date.getDate()}
                        </div>
                        <div className="space-y-1">
                          {calendarEvents
                            .filter((event) => {
                              const eventDate = new Date(event.start);
                              const matchesDate = (
                                eventDate.getDate() === date.getDate() &&
                                eventDate.getMonth() === date.getMonth() &&
                                eventDate.getFullYear() === date.getFullYear()
                              );

                              // Apply filters
                              if (!matchesDate) return false;
                              if (event.type === 'planner' && !showPlannerRequests) return false;
                              if (event.type === 'holiday' && !showHolidays) return false;

                              return true;
                            })
                            .map((event, eventIndex) => (
                              <div
                                key={eventIndex}
                                className="text-xs p-2 rounded"
                                style={{
                                  backgroundColor: `${event.color}15`,
                                  borderLeft: `3px solid ${event.color}`,
                                  color: event.color,
                                }}
                                title={event.details ? `${event.details.employeeName} - ${event.details.plannerType} (${event.details.hours}h)` : event.title}
                              >
                                {event.title}
                              </div>
                            ))}
                        </div>
                      </>
                    )}
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Forms */}
      {showHolidayForm && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg p-6 max-w-md w-full">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-xl font-semibold">Añadir Festivo</h2>
              <button
                onClick={() => setShowHolidayForm(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <form onSubmit={handleAddHoliday} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Fecha
                </label>
                <input
                  type="date"
                  value={newHoliday.date}
                  onChange={(e) => setNewHoliday({ ...newHoliday, date: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Nombre del Festivo
                </label>
                <input
                  type="text"
                  value={newHoliday.name}
                  onChange={(e) => setNewHoliday({ ...newHoliday, name: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  placeholder="Ej: Navidad"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Centro de Trabajo
                </label>
                <select
                  value={newHoliday.work_center || ''}
                  onChange={(e) => setNewHoliday({ ...newHoliday, work_center: e.target.value || null })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                >
                  <option value="">Todos los centros</option>
                  {workCenterOptions.map((center) => (
                    <option key={center} value={center}>
                      {center}
                    </option>
                  ))}
                </select>
              </div>

              <div className="flex justify-end gap-4 mt-6">
                <button
                  type="button"
                  onClick={() => setShowHolidayForm(false)}
                  className="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                >
                  Guardar
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {showPlannerForm && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg p-6 max-w-md w-full">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-xl font-semibold">Añadir Planificador</h2>
              <button
                onClick={() => setShowPlannerForm(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <form onSubmit={handleAddPlanner} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Empleado
                </label>
                <select
                  value={newPlanner.employeeId}
                  onChange={(e) => setNewPlanner({ ...newPlanner, employeeId: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  required
                >
                  <option value="">Seleccionar empleado</option>
                  {employees.map((emp) => (
                    <option key={emp.id} value={emp.id}>
                      {emp.fiscal_name}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Tipo de Planificador
                </label>
                <select
                  value={newPlanner.plannerType}
                  onChange={(e) => setNewPlanner({ ...newPlanner, plannerType: e.target.value as any })}
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
                  Fecha Inicio
                </label>
                <input
                  type="datetime-local"
                  value={newPlanner.startDate}
                  onChange={(e) => setNewPlanner({ ...newPlanner, startDate: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Fecha Fin
                </label>
                <input
                  type="datetime-local"
                  value={newPlanner.endDate}
                  onChange={(e) => setNewPlanner({ ...newPlanner, endDate: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Comentario
                </label>
                <textarea
                  value={newPlanner.comment}
                  onChange={(e) => setNewPlanner({ ...newPlanner, comment: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  rows={4}
                  required
                />
              </div>

              <div className="flex justify-end gap-4 mt-6">
                <button
                  type="button"
                  onClick={() => setShowPlannerForm(false)}
                  className="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                >
                  Guardar
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}