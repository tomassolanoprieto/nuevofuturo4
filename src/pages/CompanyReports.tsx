import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { Download, Search, FileText, AlertTriangle } from 'lucide-react';
import * as XLSX from 'xlsx';
import jsPDF from 'jspdf';
import 'jspdf-autotable';

interface DailyReport {
  date: string;
  clock_in: string;
  clock_out: string;
  break_duration: string;
  total_hours: number;
  time_type?: string;
}

interface Report {
  employee: {
    fiscal_name: string;
    email: string;
    work_centers: string[];
    document_number: string;
  };
  date: string;
  entry_type: string;
  timestamp: string;
  work_center?: string;
  total_hours?: number;
  daily_reports?: DailyReport[];
  monthly_hours?: number[];
  time_type?: string;
}

export default function CompanyReports() {
  const [reports, setReports] = useState<Report[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [reportType, setReportType] = useState<'daily' | 'annual' | 'official' | 'alarms'>('daily');
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedWorkCenter, setSelectedWorkCenter] = useState('');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [selectedEmployee, setSelectedEmployee] = useState('');
  const [employees, setEmployees] = useState<any[]>([]);
  const [workCenters, setWorkCenters] = useState<string[]>([]);
  const [hoursLimit, setHoursLimit] = useState<number>(40);
  const [selectedYear, setSelectedYear] = useState<number | null>(null);
  const [selectedTimeType, setSelectedTimeType] = useState<string>('');
  const [timeTypes, setTimeTypes] = useState<string[]>([]);

  const [isInitialLoad, setIsInitialLoad] = useState(true);

  useEffect(() => {
    const fetchInitialData = async () => {
      await fetchWorkCenters();
      await fetchEmployees();
      await fetchTimeTypes();
      setIsInitialLoad(false);
    };
    
    fetchInitialData();
  }, []);

  useEffect(() => {
    if (isInitialLoad) return; // Esperar hasta que la carga inicial termine
    
    const timer = setTimeout(() => {
      generateReport();
    }, 300); // Pequeño delay para asegurar que todo está listo
    
    return () => clearTimeout(timer);
  }, [
    reportType, searchTerm, selectedWorkCenter, 
    startDate, endDate, selectedEmployee, 
    hoursLimit, selectedYear, selectedTimeType,
    isInitialLoad // Añadir esta dependencia
  ]);
  
  useEffect(() => {
    if ((reportType === 'daily' || reportType === 'official' || reportType === 'alarms') && startDate && endDate) {
      generateReport();
    } else if (reportType === 'annual' && selectedYear) {
      generateReport();
    }
  }, [reportType, searchTerm, selectedWorkCenter, startDate, endDate, selectedEmployee, hoursLimit, selectedYear, selectedTimeType]);

  const fetchTimeTypes = async () => {
    try {
      const { data, error } = await supabase
        .from('time_entries')
        .select('time_type')
        .not('time_type', 'is', null)
        .neq('time_type', '');

      if (data) {
        const uniqueTimeTypes = [...new Set(data.map(entry => entry.time_type))];
        setTimeTypes(uniqueTimeTypes);
      }
    } catch (error) {
      console.error('Error fetching time types:', error);
    }
  };

  const fetchWorkCenters = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data } = await supabase
        .from('employee_profiles')
        .select('work_centers')
        .eq('company_id', user.id);

      if (data) {
        const uniqueWorkCenters = [...new Set(data.flatMap(emp => emp.work_centers || []))];
        setWorkCenters(uniqueWorkCenters);
      }
    } catch (error) {
      console.error('Error fetching work centers:', error);
    }
  };

  const fetchEmployees = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      let query = supabase
        .from('employee_profiles')
        .select('*')
        .eq('company_id', user.id)
        .eq('is_active', true);

      const { data } = await query;
      if (data) {
        setEmployees(data);
      }
    } catch (error) {
      console.error('Error fetching employees:', error);
    }
  };

  const generateReport = async () => {
  setIsLoading(true);

  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    let employeeQuery = supabase
      .from('employee_profiles')
      .select('*')
      .eq('company_id', user.id)
      .eq('is_active', true);

    if (selectedWorkCenter) {
      employeeQuery = employeeQuery.contains('work_centers', [selectedWorkCenter]);
    }

    if (searchTerm) {
      employeeQuery = employeeQuery.ilike('fiscal_name', `%${searchTerm}%`);
    }

    const { data: employees } = await employeeQuery;
    if (!employees) return;

    let timeEntriesQuery = supabase
      .from('time_entries')
      .select('*')
      .in('employee_id', employees.map(emp => emp.id))
      .eq('is_active', true)
      .gte('timestamp', reportType === 'annual' ? new Date(selectedYear || new Date().getFullYear(), 0, 1).toISOString() : startDate)
      .lte('timestamp', reportType === 'annual' ? new Date(selectedYear || new Date().getFullYear(), 11, 31).toISOString() : endDate)
      .order('timestamp', { ascending: true });

    if (selectedTimeType) {
      timeEntriesQuery = timeEntriesQuery.eq('time_type', selectedTimeType);
    }

    const { data: timeEntries } = await timeEntriesQuery;
    if (!timeEntries) return;

    // Función centralizada para procesar registros de tiempo
    const processTimeEntries = (employeeId: string) => {
  const employeeEntries = timeEntries
    .filter(entry => entry.employee_id === employeeId)
    .sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());

  const dailyResults: any[] = [];
  let currentEntry: any = null;
  let pendingClockOuts: any[] = [];

  // Función para calcular horas trabajadas
  const getHoursWorked = (start: string, end: string, breakMs: number) => {
    const startTime = new Date(start).getTime();
    const endTime = new Date(end).getTime();
    return ((endTime - startTime) / (1000 * 60 * 60)) - (breakMs / (1000 * 60 * 60));
  };

  for (const entry of employeeEntries) {
    const dateKey = entry.timestamp.split('T')[0];
    const entryTime = new Date(entry.timestamp);

    switch (entry.entry_type) {
      case 'clock_in':
        // Cerrar entrada anterior si existe
        if (currentEntry && currentEntry.clockIn && !currentEntry.clockOut) {
          const endOfDay = new Date(currentEntry.date);
          endOfDay.setHours(23, 59, 59, 999);
          currentEntry.clockOut = endOfDay.toISOString();
          currentEntry.hours = getHoursWorked(
            currentEntry.clockIn,
            currentEntry.clockOut,
            currentEntry.breakDuration
          );
          dailyResults.push(currentEntry);
        }
        
        // Crear nueva entrada
        currentEntry = {
          date: dateKey,
          dateObj: new Date(dateKey),
          clockIn: entry.timestamp,
          breakDuration: 0,
          timeType: entry.time_type,
          clockOut: undefined,
          hours: 0
        };
        break;

      case 'clock_out':
        if (currentEntry && currentEntry.clockIn && !currentEntry.clockOut) {
          // Asignar salida a entrada actual
          currentEntry.clockOut = entry.timestamp;
          currentEntry.hours = getHoursWorked(
            currentEntry.clockIn,
            currentEntry.clockOut,
            currentEntry.breakDuration
          );
          dailyResults.push(currentEntry);
          currentEntry = null;
        } else {
          // Guardar salida pendiente
          pendingClockOuts.push(entry);
        }
        break;

      case 'break_start':
        if (currentEntry) {
          currentEntry.breakStart = entry.timestamp;
        }
        break;

      case 'break_end':
        if (currentEntry && currentEntry.breakStart) {
          const breakStart = new Date(currentEntry.breakStart).getTime();
          const breakEnd = entryTime.getTime();
          currentEntry.breakDuration += (breakEnd - breakStart);
          currentEntry.breakStart = undefined;
        }
        break;
    }
  }

  // Procesar entrada pendiente final
  if (currentEntry && currentEntry.clockIn && !currentEntry.clockOut) {
    const endOfDay = new Date(currentEntry.date);
    endOfDay.setHours(23, 59, 59, 999);
    currentEntry.clockOut = endOfDay.toISOString();
    currentEntry.hours = getHoursWorked(
      currentEntry.clockIn,
      currentEntry.clockOut,
      currentEntry.breakDuration
    );
    dailyResults.push(currentEntry);
  }

  // Procesar salidas pendientes (sin entrada correspondiente)
  pendingClockOuts.forEach(clockOut => {
    dailyResults.push({
      date: clockOut.timestamp.split('T')[0],
      dateObj: new Date(clockOut.timestamp.split('T')[0]),
      clockIn: undefined,
      clockOut: clockOut.timestamp,
      breakDuration: 0,
      hours: 0,
      timeType: clockOut.time_type
    });
  });

  // Agrupar entradas por fecha
  const entriesByDate = employeeEntries.reduce((acc, entry) => {
    const date = entry.timestamp.split('T')[0];
    if (!acc[date]) acc[date] = [];
    acc[date].push(entry);
    return acc;
  }, {} as Record<string, any[]>);

  return {
    dailyResults,
    entriesByDate
  };
};

let reportData: Report[] = [];

    // Generar los diferentes tipos de reportes usando la lógica centralizada
    switch (reportType) {
      case 'official': {
  if (!selectedEmployee) break;

  const employee = employees.find(emp => emp.id === selectedEmployee);
  if (!employee) break;

  const start = new Date(startDate);
  const end = new Date(endDate);
  const daysInRange = [];
  for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
    daysInRange.push(new Date(d));
  }

  const { dailyResults } = processTimeEntries(selectedEmployee);

  // Crear un mapa de resultados por día para búsqueda rápida
  const resultsByDate = new Map<string, {
    clockIn?: string;
    clockOut?: string;
    breakDuration: number;
    hours: number;
    timeType?: string;
  }>();
  
  dailyResults.forEach(day => {
    resultsByDate.set(day.date, {
      clockIn: day.clockIn,
      clockOut: day.clockOut,
      breakDuration: day.breakDuration,
      hours: day.hours,
      timeType: day.timeType
    });
  });

  // Generar reporte para todos los días del rango
  const dailyReports: DailyReport[] = daysInRange.map(date => {
    const dateKey = date.toISOString().split('T')[0];
    const dayData = resultsByDate.get(dateKey);

    return {
      date: date.toLocaleDateString('es-ES', {
        weekday: 'long',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit'
      }),
      clock_in: dayData?.clockIn ? new Date(dayData.clockIn).toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' }) : '',
      clock_out: dayData?.clockOut ? new Date(dayData.clockOut).toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' }) : '',
      break_duration: dayData?.breakDuration ? `${Math.floor(dayData.breakDuration / (1000 * 60 * 60))}:${Math.floor((dayData.breakDuration % (1000 * 60 * 60)) / (1000 * 60)).toString().padStart(2, '0')}` : '',
      total_hours: dayData?.hours || 0,
      time_type: dayData?.timeType || ''
    };
  });

  reportData = [{
    employee: {
      fiscal_name: employee.fiscal_name,
      email: employee.email,
      work_centers: employee.work_centers,
      document_number: employee.document_number
    },
    date: startDate,
    entry_type: '',
    timestamp: '',
    daily_reports: dailyReports
  }];
  break;
}

      case 'daily': {
        reportData = employees.map(employee => {
          const { dailyResults } = processTimeEntries(employee.id);
          const totalHours = dailyResults.reduce((sum, day) => sum + day.hours, 0);
          
          return {
            employee: {
              fiscal_name: employee.fiscal_name,
              email: employee.email,
              work_centers: employee.work_centers,
              document_number: employee.document_number
            },
            date: `${startDate} - ${endDate}`,
            entry_type: '',
            timestamp: '',
            total_hours: totalHours,
            time_type: selectedTimeType || 'Todos'
          };
        });
        break;
      }

      case 'annual': {
        reportData = employees.map(employee => {
          const { dailyResults } = processTimeEntries(employee.id);
          const totalHoursByMonth = Array(12).fill(0);
          
          dailyResults.forEach(day => {
            const month = day.dateObj.getMonth();
            totalHoursByMonth[month] += day.hours;
          });

          return {
            employee: {
              fiscal_name: employee.fiscal_name,
              email: employee.email,
              work_centers: employee.work_centers,
              document_number: employee.document_number
            },
            date: `Año ${selectedYear}`,
            entry_type: '',
            timestamp: '',
            total_hours: totalHoursByMonth.reduce((acc, hours) => acc + hours, 0),
            monthly_hours: totalHoursByMonth,
            time_type: selectedTimeType || 'Todos'
          };
        });
        break;
      }

      case 'alarms': {
        reportData = employees.map(employee => {
          const { dailyResults } = processTimeEntries(employee.id);
          const totalHours = dailyResults.reduce((sum, day) => sum + day.hours, 0);
          
          return {
            employee: {
              fiscal_name: employee.fiscal_name,
              email: employee.email,
              work_centers: employee.work_centers,
              document_number: employee.document_number
            },
            date: '-',
            entry_type: '-',
            timestamp: '-',
            total_hours: totalHours,
            time_type: selectedTimeType || ''
          };
        }).filter(({ total_hours }) => total_hours > hoursLimit)
          .map(({ employee, total_hours }) => ({
            employee,
            date: '-',
            entry_type: '-',
            timestamp: '-',
            total_hours
          }));
        break;
      }
    }

    setReports(reportData);
  } catch (error) {
    console.error('Error generating report:', error);
  } finally {
    setIsLoading(false);
  }
};

  const handleExport = () => {
    if (reportType === 'official') {
      if (!selectedEmployee || !startDate || !endDate) {
        alert('Por favor seleccione un empleado y el rango de fechas');
        return;
      }

      const report = reports[0];
      if (!report || !report.daily_reports) return;

      const doc = new jsPDF();

      doc.setFontSize(14);
      doc.text('Listado mensual del registro de jornada', 105, 20, { align: 'center' });

      doc.setFontSize(10);
      const tableData = [
        ['Empresa: NUEVO FUTURO', `Trabajador: ${report.employee.fiscal_name}`],
        ['C.I.F/N.I.F: G28309862', `N.I.F: ${report.employee.document_number}`],
        [`Centro de Trabajo: ${report.employee.work_centers.join(', ')}`],
        ['C.C.C:', `Mes y Año: ${new Date(startDate).toLocaleDateString('es-ES', { month: '2-digit', year: 'numeric' })}`]
      ];

      doc.autoTable({
        startY: 30,
        head: [],
        body: tableData,
        theme: 'plain',
        styles: {
          cellPadding: 2,
          fontSize: 10
        },
        columnStyles: {
          0: { cellWidth: 95 },
          1: { cellWidth: 95 }
        }
      });

      const recordsData = report.daily_reports.map(day => [
        day.date,
        day.clock_in,
        day.clock_out,
        day.break_duration,
        day.total_hours ? 
          `${Math.floor(day.total_hours)}:${Math.round((day.total_hours % 1) * 60).toString().padStart(2, '0')}` : 
          '0:00',
        day.time_type || ''
      ]);

      doc.autoTable({
        startY: doc.lastAutoTable.finalY + 10,
        head: [['DIA', 'ENTRADA', 'SALIDA', 'PAUSAS', 'HORAS ORDINARIAS', 'TIPO']],
        body: recordsData,
        theme: 'grid',
        styles: {
          cellPadding: 2,
          fontSize: 8,
          halign: 'center'
        },
        columnStyles: {
          0: { cellWidth: 40 },
          1: { cellWidth: 30 },
          2: { cellWidth: 30 },
          3: { cellWidth: 30 },
          4: { cellWidth: 30 },
          5: { cellWidth: 30 }
        }
      });

      const totalHours = report.daily_reports.reduce((acc, day) => acc + (day.total_hours || 0), 0);
      const hours = Math.floor(totalHours);
      const minutes = Math.round((totalHours % 1) * 60);
      const totalFormatted = `${hours}:${minutes.toString().padStart(2, '0')}`;

      doc.autoTable({
        startY: doc.lastAutoTable.finalY,
        head: [],
        body: [['TOTAL HORAS', '', '', '', totalFormatted, '']],
        theme: 'grid',
        styles: {
          cellPadding: 2,
          fontSize: 8,
          halign: 'center',
          fontStyle: 'bold'
        },
        columnStyles: {
          0: { cellWidth: 40 },
          1: { cellWidth: 30 },
          2: { cellWidth: 30 },
          3: { cellWidth: 30 },
          4: { cellWidth: 30 },
          5: { cellWidth: 30 }
        }
      });

      doc.setFontSize(10);
      doc.text('Firma de la Empresa:', 40, doc.lastAutoTable.finalY + 30);
      doc.text('Firma del Trabajador:', 140, doc.lastAutoTable.finalY + 30);

      doc.setFontSize(8);
      doc.text(`En Madrid, a ${new Date().toLocaleDateString('es-ES', { 
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        year: 'numeric'
      })}`, 14, doc.lastAutoTable.finalY + 60);

      doc.setFontSize(6);
      const legalText = 'Registro realizado en cumplimiento del Real Decreto-ley 8/2019, de 8 de marzo, de medidas urgentes de protección social y de lucha contra la precariedad laboral en la jornada de trabajo ("BOE" núm. 61 de 12 de marzo), la regulación de forma expresa en el artículo 34 del texto refundido de la Ley del Estatuto de los Trabajadores (ET), la obligación de las empresas de registrar diariamente la jornada laboral.';
      doc.text(legalText, 14, doc.lastAutoTable.finalY + 70, {
        maxWidth: 180,
        align: 'justify'
      });

      doc.save(`informe_oficial_${report.employee.fiscal_name}_${startDate}.pdf`);
    } else {
      const exportData = reports.map(report => ({
        'Nombre': report.employee.fiscal_name,
        'Email': report.employee.email,
        'Centros de Trabajo': report.employee.work_centers.join(', '),
        'Tipo de Fichaje': report.time_type || 'Todos',
        'Fecha': report.date,
        'Tipo': report.entry_type,
        'Hora': report.timestamp,
        'Centro de Trabajo': report.work_center || '',
        ...(report.total_hours ? { 'Horas Totales': report.total_hours } : {}),
        ...(report.monthly_hours ? {
          'Enero': report.monthly_hours[0],
          'Febrero': report.monthly_hours[1],
          'Marzo': report.monthly_hours[2],
          'Abril': report.monthly_hours[3],
          'Mayo': report.monthly_hours[4],
          'Junio': report.monthly_hours[5],
          'Julio': report.monthly_hours[6],
          'Agosto': report.monthly_hours[7],
          'Septiembre': report.monthly_hours[8],
          'Octubre': report.monthly_hours[9],
          'Noviembre': report.monthly_hours[10],
          'Diciembre': report.monthly_hours[11]
        } : {})
      }));

      const ws = XLSX.utils.json_to_sheet(exportData);
      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, ws, 'Informe');
      
      const reportName = `informe_${reportType}_${new Date().toISOString().split('T')[0]}.xlsx`;
      XLSX.writeFile(wb, reportName);
    }
  };

  return (
    <div className="p-8">
      <div className="max-w-7xl mx-auto">
        <div className="mb-8">
          <h1 className="text-2xl font-bold mb-2">Informes</h1>
          <p className="text-gray-600">Genera y exporta informes detallados</p>
        </div>

        <div className="mb-6 flex gap-4">
          <button
            onClick={() => setReportType('daily')}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg ${
              reportType === 'daily'
                ? 'bg-blue-600 text-white'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            <FileText className="w-5 h-5" />
            Resumen Diario
          </button>
          <button
            onClick={() => setReportType('annual')}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg ${
              reportType === 'annual'
                ? 'bg-blue-600 text-white'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            <FileText className="w-5 h-5" />
            Resumen Anual
          </button>
          <button
            onClick={() => setReportType('official')}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg ${
              reportType === 'official'
                ? 'bg-blue-600 text-white'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            <FileText className="w-5 h-5" />
            Informe Oficial
          </button>
          <button
            onClick={() => setReportType('alarms')}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg ${
              reportType === 'alarms'
                ? 'bg-blue-600 text-white'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            <AlertTriangle className="w-5 h-5" />
            Alarmas
          </button>
        </div>

        <div className="bg-white p-6 rounded-xl shadow-sm space-y-4 mb-6">
          <h2 className="text-lg font-semibold">Filtros</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {reportType === 'official' ? (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Empleado
                </label>
                <select
                  value={selectedEmployee}
                  onChange={(e) => setSelectedEmployee(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                >
                  <option value="">Seleccionar empleado</option>
                  {employees.map((emp) => (
                    <option key={emp.id} value={emp.id}>
                      {emp.fiscal_name}
                    </option>
                  ))}
                </select>
              </div>
            ) : (
              <>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Centro de Trabajo
                  </label>
                  <select
                    value={selectedWorkCenter}
                    onChange={(e) => setSelectedWorkCenter(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  >
                    <option value="">Todos los centros</option>
                    {workCenters.map((center) => (
                      <option key={center} value={center}>
                        {center}
                      </option>
                    ))}
                  </select>
                </div>

                {(reportType === 'daily' || reportType === 'annual') && (
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Tipo de Fichaje
                    </label>
                    <select
                      value={selectedTimeType}
                      onChange={(e) => setSelectedTimeType(e.target.value)}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    >
                      <option value="">Todos los tipos</option>
                      {timeTypes.map((type) => (
                        <option key={type} value={type}>
                          {type}
                        </option>
                      ))}
                    </select>
                  </div>
                )}

                {reportType === 'alarms' && (
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Límite de Horas
                    </label>
                    <input
                      type="number"
                      value={hoursLimit.toString()}
                      onChange={(e) => {
                        const value = parseInt(e.target.value);
                        if (!isNaN(value) && value > 0) {
                          setHoursLimit(value);
                        }
                      }}
                      min="1"
                      step="1"
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    />
                  </div>
                )}
              </>
            )}

            {(reportType === 'daily' || reportType === 'official' || reportType === 'alarms') && (
              <>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Fecha Inicio
                  </label>
                  <input
                    type="date"
                    value={startDate}
                    onChange={(e) => setStartDate(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Fecha Fin
                  </label>
                  <input
                    type="date"
                    value={endDate}
                    onChange={(e) => setEndDate(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  />
                </div>
              </>
            )}

            {reportType === 'annual' && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Año
                </label>
                <select
                  value={selectedYear || ''}
                  onChange={(e) => setSelectedYear(parseInt(e.target.value))}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                >
                  <option value="">Seleccionar año</option>
                  {Array.from({ length: 10 }, (_, i) => (
                    <option key={i} value={new Date().getFullYear() - i}>
                      {new Date().getFullYear() - i}
                    </option>
                  ))}
                </select>
              </div>
            )}
          </div>
        </div>

        <div className="mb-6">
          <button
            onClick={handleExport}
            className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
          >
            <Download className="w-5 h-5" />
            {reportType === 'official' ? 'Generar PDF' : 'Exportar a Excel'}
          </button>
        </div>

        {reportType !== 'official' && (
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
                    {(reportType === 'daily' || reportType === 'annual') && (
                      <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Tipo de Fichaje
                      </th>
                    )}
                    {reportType === 'daily' ? (
                      <>
                        <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Fechas
                        </th>
                        <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Total Horas
                        </th>
                      </>
                    ) : reportType === 'annual' ? (
                      <>
                        <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Enero
                        </th>
                        <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Febrero
                        </th>
                        <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Marzo
                        </th>
                        <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Abril
                        </th>
                        <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Mayo
                        </th>
                        <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Junio
                        </th>
                        <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Julio
                        </th>
                        <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Agosto
                        </th>
                        <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Septiembre
                        </th>
                        <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Octubre
                        </th>
                        <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Noviembre
                        </th>
                        <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Diciembre
                        </th>
                        <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Total Horas
                        </th>
                      </>
                    ) : (
                      <th className="px-6 py-3 bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Horas Totales
                      </th>
                    )}
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {isLoading ? (
                    <tr>
                      <td colSpan={reportType === 'annual' ? 16 : (reportType === 'daily' ? 7 : 6)} className="px-6 py-4 text-center">
                        Cargando...
                      </td>
                    </tr>
                  ) : reports.length === 0 ? (
                    <tr>
                      <td colSpan={reportType === 'annual' ? 16 : (reportType === 'daily' ? 7 : 6)} className="px-6 py-4 text-center">
                        No hay datos para mostrar
                      </td>
                    </tr>
                  ) : (
                    reports.map((report, index) => (
                      <tr key={index} className="hover:bg-gray-50">
                        <td className="px-6 py-4 whitespace-nowrap">
                          {report.employee.fiscal_name}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {report.employee.email}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {report.employee.work_centers.join(', ')}
                        </td>
                        {(reportType === 'daily' || reportType === 'annual') && (
                          <td className="px-6 py-4 whitespace-nowrap">
                            {report.time_type || 'Todos'}
                          </td>
                        )}
                        {reportType === 'daily' ? (
                          <>
                            <td className="px-6 py-4 whitespace-nowrap">
                              {report.date}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap">
                              {report.total_hours?.toFixed(2)} h
                            </td>
                          </>
                        ) : reportType === 'annual' ? (
                          <>
                            {report.monthly_hours?.map((hours, i) => (
                              <td key={i} className="px-6 py-4 whitespace-nowrap">
                                {hours.toFixed(2)} h
                              </td>
                            ))}
                            <td className="px-6 py-4 whitespace-nowrap">
                              {report.total_hours?.toFixed(2)} h
                            </td>
                          </>
                        ) : (
                          <td className="px-6 py-4 whitespace-nowrap">
                            {report.total_hours?.toFixed(2)} h
                          </td>
                        )}
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}