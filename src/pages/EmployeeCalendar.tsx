import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { Calendar, FileText, ChevronLeft, ChevronRight } from 'lucide-react';

interface CalendarEvent {
  title: string;
  start: string;
  end: string;
  color: string;
  type: 'planner' | 'holiday';
  details?: {
    planner_type?: string;
    comment?: string;
    status?: string;
  };
}

export default function EmployeeCalendar() {
  const [calendarEvents, setCalendarEvents] = useState<CalendarEvent[]>([]);
  const [currentDate, setCurrentDate] = useState(new Date());
  const [showPlannerRequests, setShowPlannerRequests] = useState(true);
  const [showHolidays, setShowHolidays] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchCalendarEvents();
  }, [currentDate, showPlannerRequests, showHolidays]);

  const fetchCalendarEvents = async () => {
    try {
      setLoading(true);
      setError(null);

      const employeeId = localStorage.getItem('employeeId');
      if (!employeeId) {
        throw new Error('No se encontró el ID del empleado');
      }

      const startOfMonth = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1);
      const endOfMonth = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0);

      startOfMonth.setHours(0, 0, 0, 0);
      endOfMonth.setHours(23, 59, 59, 999);

      // Get employee's work centers
      const { data: employeeData, error: employeeError } = await supabase
        .from('employee_profiles')
        .select('work_centers')
        .eq('id', employeeId)
        .single();

      if (employeeError) throw employeeError;

      // Fetch planner requests
      const { data: plannerData, error: plannerError } = await supabase
        .from('planner_requests')
        .select('*')
        .eq('employee_id', employeeId)
        .eq('status', 'approved')
        .or(`start_date.lte.${endOfMonth.toISOString()},end_date.gte.${startOfMonth.toISOString()}`);

      if (plannerError) throw plannerError;

      // Fetch holidays
      const { data: holidaysData, error: holidaysError } = await supabase
        .from('holidays')
        .select('*')
        .gte('date', startOfMonth.toISOString())
        .lte('date', endOfMonth.toISOString())
        .or(`work_center.is.null,work_center.in.(${employeeData.work_centers.map(wc => `"${wc}"`).join(',')})`);

      if (holidaysError) throw holidaysError;

      // Process planner requests
      const events: CalendarEvent[] = [];

      if (showPlannerRequests) {
        (plannerData || []).forEach(p => {
          const start = new Date(p.start_date);
          const end = new Date(p.end_date);
          let current = new Date(start);

          while (current <= end) {
            if (current >= startOfMonth && current <= endOfMonth) {
              events.push({
                title: `${p.planner_type}`,
                start: current.toISOString(),
                end: current.toISOString(),
                color: '#22c55e',
                type: 'planner',
                details: {
                  planner_type: p.planner_type,
                  comment: p.comment,
                  status: p.status
                }
              });
            }
            current.setDate(current.getDate() + 1);
          }
        });
      }

      // Process holidays
      if (showHolidays) {
        (holidaysData || []).forEach(h => {
          events.push({
            title: h.name + (h.work_center ? ` (${h.work_center})` : ' (Todos los centros)'),
            start: h.date,
            end: h.date,
            color: '#f97316',
            type: 'holiday'
          });
        });
      }

      setCalendarEvents(events);
    } catch (err) {
      console.error('Error fetching calendar events:', err);
      setError(err instanceof Error ? err.message : 'Error al cargar los eventos');
    } finally {
      setLoading(false);
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
    setCurrentDate(date => {
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
    <div className="max-w-7xl mx-auto px-4 py-8">
      <div className="bg-white rounded-xl shadow-lg p-6">
        <h2 className="text-2xl font-bold mb-6">Mi Calendario</h2>

        {error && (
          <div className="mb-6 p-4 bg-red-50 border-l-4 border-red-500 text-red-700">
            {error}
          </div>
        )}

        {/* Legend */}
        <div className="mb-6 flex items-center gap-4">
          <button
            onClick={() => setShowPlannerRequests(!showPlannerRequests)}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg ${
              showPlannerRequests ? 'bg-green-50 text-green-600' : 'bg-gray-50 text-gray-600'
            }`}
          >
            <FileText className="w-5 h-5" />
            <span className="text-sm">Planificador</span>
          </button>

          <button
            onClick={() => setShowHolidays(!showHolidays)}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg ${
              showHolidays ? 'bg-orange-50 text-orange-600' : 'bg-gray-50 text-gray-600'
            }`}
          >
            <Calendar className="w-5 h-5" />
            <span className="text-sm">Festivos</span>
          </button>
        </div>

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
          {['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'].map(day => (
            <div key={day} className="text-center font-semibold py-2">
              {day}
            </div>
          ))}
          {/* Calendar Days */}
          {loading ? (
            <div className="col-span-7 py-20 text-center text-gray-500">
              Cargando eventos...
            </div>
          ) : (
            getDaysInMonth(currentDate).map((date, index) => (
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
                        .filter(event => {
                          const eventDate = new Date(event.start);
                          return (
                            eventDate.getDate() === date.getDate() &&
                            eventDate.getMonth() === date.getMonth() &&
                            eventDate.getFullYear() === date.getFullYear()
                          );
                        })
                        .map((event, eventIndex) => (
                          <div
                            key={eventIndex}
                            className="text-xs p-2 rounded"
                            style={{ 
                              backgroundColor: `${event.color}15`,
                              borderLeft: `3px solid ${event.color}`,
                              color: event.color 
                            }}
                            title={event.details?.comment || event.title}
                          >
                            {event.title}
                          </div>
                        ))}
                    </div>
                  </>
                )}
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}