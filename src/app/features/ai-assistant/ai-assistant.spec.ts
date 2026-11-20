import { DestroyableInjector, Injector, runInInjectionContext, signal } from '@angular/core';
import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { of, throwError } from 'rxjs';
import { AiAssistant } from './ai-assistant';
import { AuthService } from '../../core/services/auth.service';
import { PermissionsService } from '../../core/services/permissions.service';
import { AsistenciaTratamientoService } from '../../core/services/asistencia-tratamiento.service';
import {
  EvaluacionTratamientoResponse,
  HistorialEvaluacionResponse,
} from '../../core/models/asistencia-tratamiento.models';

describe('AiAssistant Component (CU18 - Angular Web)', () => {
  let injector: DestroyableInjector;

  // Mocks de servicios reactivos
  const evaluacionActualSignal = signal<EvaluacionTratamientoResponse | null>(null);
  const isLoadingSignal = signal<boolean>(false);
  const errorMessageSignal = signal<string | null>(null);
  const errorCodeSignal = signal<string | null>(null);
  const retryAfterSecondsSignal = signal<number | null>(null);

  const historialSignal = signal<HistorialEvaluacionResponse | null>(null);
  const isLoadingHistorialSignal = signal<boolean>(false);
  const historialErrorSignal = signal<string | null>(null);

  const selectedDetalleSignal = signal<EvaluacionTratamientoResponse | null>(null);
  const isLoadingDetalleSignal = signal<boolean>(false);
  const detalleErrorSignal = signal<string | null>(null);

  const mockAsistenciaService = {
    evaluacionActual: evaluacionActualSignal,
    isLoading: isLoadingSignal,
    errorMessage: errorMessageSignal,
    errorCode: errorCodeSignal,
    retryAfterSeconds: retryAfterSecondsSignal,

    historial: historialSignal,
    isLoadingHistorial: isLoadingHistorialSignal,
    historialError: historialErrorSignal,

    selectedDetalle: selectedDetalleSignal,
    isLoadingDetalle: isLoadingDetalleSignal,
    detalleError: detalleErrorSignal,

    evaluar: vi.fn(),
    getHistorial: vi.fn(),
    getEvaluacionById: vi.fn(),
    limpiarDetalle: vi.fn(() => selectedDetalleSignal.set(null)),
  };

  const isPacienteSignal = signal<boolean>(true);
  const isDoctorSignal = signal<boolean>(false);
  const mockAuthService = {
    isPaciente: isPacienteSignal,
    isDoctor: isDoctorSignal,
    isAuthenticated: vi.fn(() => true),
  };

  const hasPermissionMock = vi.fn((perm: string) => perm === 'assistance:evaluate' || perm === 'assistance:read');
  const mockPermissionsService = {
    hasPermission: hasPermissionMock,
  };

  // Datos mock para pruebas
  const evaluacion3CMock: EvaluacionTratamientoResponse = {
    id_evaluacion: 50,
    id_paciente: 1,
    fecha_evaluacion: '2026-11-04T10:00:00Z',
    estado_evaluacion: 'COMPLETADA',
    nivel_riesgo_global: 'ALTO',
    total_medicamentos_analizados: 2,
    total_alertas_detectadas: 1,
    resumen_ejecutivo: 'Alerta crítica detectada',
    aviso_legal: 'Sugerencias de apoyo. La IA nunca modifica diagnósticos.',
    medicamentos_analizados: [
      { nombre: 'Ibuprofeno', principio_activo: 'Ibuprofeno', dosis: '400mg', frecuencia: 'Cada 8h' },
      { nombre: 'Aspirina', principio_activo: 'Aspirina', dosis: '100mg', frecuencia: 'Cada 24h' },
    ],
    alertas: [
      {
        id_alerta: 1,
        principio_activo_1: 'Ibuprofeno',
        principio_activo_2: 'Aspirina',
        medicamento_1_nombre: 'Ibuprofeno',
        medicamento_2_nombre: 'Aspirina',
        severidad: 'GRAVE',
        color_alerta: 'ROJO',
        mensaje_alerta: 'Riesgo de interacción: aumento de riesgo de sangrado',
        pauta_precaucion: 'Consulte a su médico inmediatamente.',
      },
    ],
    recomendaciones: [
      {
        id_recomendacion: 1,
        categoria: 'SIGNOS_ALARMA',
        titulo: 'Vigilar sangrado',
        detalle: 'Acuda a urgencias si presenta sangrado.',
        origen: 'IA_GENERATIVA',
      },
    ],
  };

  const evaluacionSinRiesgoMock: EvaluacionTratamientoResponse = {
    id_evaluacion: 51,
    id_paciente: 1,
    fecha_evaluacion: '2026-11-04T10:00:00Z',
    estado_evaluacion: 'COMPLETADA',
    nivel_riesgo_global: 'SIN_RIESGO',
    total_medicamentos_analizados: 1,
    total_alertas_detectadas: 0,
    resumen_ejecutivo: 'No se detectaron interacciones adversas entre sus medicamentos vigentes.',
    aviso_legal: 'Sugerencias de apoyo.',
    medicamentos_analizados: [
      { nombre: 'Paracetamol', principio_activo: 'Paracetamol', dosis: '500mg', frecuencia: 'Cada 8h' },
    ],
    alertas: [],
    recomendaciones: [],
  };

  const evaluacionSinTratamientoMock: EvaluacionTratamientoResponse = {
    id_evaluacion: null,
    id_paciente: 1,
    fecha_evaluacion: '2026-11-04T10:00:00Z',
    estado_evaluacion: 'SIN_TRATAMIENTO_VIGENTE',
    nivel_riesgo_global: 'SIN_RIESGO',
    total_medicamentos_analizados: 0,
    total_alertas_detectadas: 0,
    resumen_ejecutivo: 'No cuentas con recetas vigentes registradas en la clínica.',
    aviso_legal: 'Sugerencias de apoyo.',
    medicamentos_analizados: [],
    alertas: [],
    recomendaciones: [],
  };

  const historialMock: HistorialEvaluacionResponse = {
    items: [
      {
        id_evaluacion: 50,
        id_paciente: 1,
        fecha_evaluacion: '2026-11-04T10:00:00Z',
        estado_evaluacion: 'COMPLETADA',
        nivel_riesgo_global: 'ALTO',
        total_medicamentos_analizados: 2,
        total_alertas_detectadas: 1,
        resumen_ejecutivo: 'Alerta crítica detectada',
      },
      {
        id_evaluacion: 51,
        id_paciente: 1,
        fecha_evaluacion: '2026-11-04T09:00:00Z',
        estado_evaluacion: 'COMPLETADA',
        nivel_riesgo_global: 'SIN_RIESGO',
        total_medicamentos_analizados: 1,
        total_alertas_detectadas: 0,
        resumen_ejecutivo: 'Sin interacciones',
      },
    ],
    total: 2,
    page: 1,
    limit: 10,
    total_paginas: 2,
  };

  function createComponent(): AiAssistant {
    injector = Injector.create({
      providers: [
        { provide: AuthService, useValue: mockAuthService },
        { provide: PermissionsService, useValue: mockPermissionsService },
        { provide: AsistenciaTratamientoService, useValue: mockAsistenciaService },
      ],
    });
    return runInInjectionContext(injector, () => new AiAssistant());
  }

  beforeEach(() => {
    vi.clearAllMocks();
    evaluacionActualSignal.set(null);
    isLoadingSignal.set(false);
    errorMessageSignal.set(null);
    errorCodeSignal.set(null);
    retryAfterSecondsSignal.set(null);

    historialSignal.set(null);
    isLoadingHistorialSignal.set(false);
    historialErrorSignal.set(null);

    selectedDetalleSignal.set(null);
    isLoadingDetalleSignal.set(false);
    detalleErrorSignal.set(null);

    isPacienteSignal.set(true);
    isDoctorSignal.set(false);

    mockAsistenciaService.evaluar.mockReturnValue(of(evaluacion3CMock));
    mockAsistenciaService.getHistorial.mockReturnValue(of(historialMock));
    mockAsistenciaService.getEvaluacionById.mockReturnValue(of(evaluacion3CMock));
  });

  afterEach(() => {
    if (injector) {
      injector.destroy();
    }
  });

  it('Escenario 3C Principal: evalúa Ibuprofeno + Aspirina, recibe ALTO riesgo y gestiona modal de urgencia', () => {
    const comp = createComponent();
    expect(comp.puedeEvaluar()).toBe(true);
    expect(comp.modalUrgenciaAbierto()).toBe(false);

    comp.solicitarEvaluacion();
    expect(mockAsistenciaService.evaluar).toHaveBeenCalledWith(false);

    // Simulamos respuesta con alerta GRAVE
    evaluacionActualSignal.set(evaluacion3CMock);
    expect(comp.evaluacionActual()?.nivel_riesgo_global).toBe('ALTO');
    expect(comp.evaluacionActual()?.alertas.length).toBe(1);
    expect(comp.evaluacionActual()?.alertas[0].severidad).toBe('GRAVE');
    expect(comp.getIconoSeveridad('GRAVE')).toBe('shield');

    // Apertura y cierre del diálogo "Qué hacer ante una urgencia"
    comp.abrirModalUrgencia();
    expect(comp.modalUrgenciaAbierto()).toBe(true);

    comp.cerrarModalUrgencia();
    expect(comp.modalUrgenciaAbierto()).toBe(false);
  });

  it('Criterio 5: sin interacciones muestra estado SIN_RIESGO y mensaje claro', () => {
    const comp = createComponent();
    evaluacionActualSignal.set(evaluacionSinRiesgoMock);

    expect(comp.evaluacionActual()?.nivel_riesgo_global).toBe('SIN_RIESGO');
    expect(comp.evaluacionActual()?.total_alertas_detectadas).toBe(0);
    expect(comp.getIconoRiesgo('SIN_RIESGO')).toBe('check_circle');
  });

  it('Maneja estado SIN_TRATAMIENTO_VIGENTE adecuadamente', () => {
    const comp = createComponent();
    evaluacionActualSignal.set(evaluacionSinTratamientoMock);

    expect(comp.evaluacionActual()?.estado_evaluacion).toBe('SIN_TRATAMIENTO_VIGENTE');
    expect(comp.evaluacionActual()?.total_medicamentos_analizados).toBe(0);
  });

  it('Maneja modo DEGRADADO_REGLAS_BASE con reglas base activas', () => {
    const comp = createComponent();
    const degradadoMock: EvaluacionTratamientoResponse = {
      ...evaluacion3CMock,
      estado_evaluacion: 'DEGRADADO_REGLAS_BASE',
    };
    evaluacionActualSignal.set(degradadoMock);

    expect(comp.evaluacionActual()?.estado_evaluacion).toBe('DEGRADADO_REGLAS_BASE');
  });

  it('Refleja error 429 RATE_LIMIT_EXCEEDED sin permitir solicitudes duplicadas si carga', () => {
    const comp = createComponent();
    errorCodeSignal.set('RATE_LIMIT_EXCEEDED');
    retryAfterSecondsSignal.set(3600);
    errorMessageSignal.set('Has alcanzado el límite de 10 evaluaciones por hora.');

    expect(comp.errorCode()).toBe('RATE_LIMIT_EXCEEDED');
    expect(comp.retryAfterSeconds()).toBe(3600);

    // Si isLoading está activo, no debe ejecutar evaluar
    isLoadingSignal.set(true);
    comp.solicitarEvaluacion();
    expect(mockAsistenciaService.evaluar).not.toHaveBeenCalled();
  });

  it('Permite reintentar con forzarRecalculo=true ante error de comunicación', () => {
    const comp = createComponent();
    errorMessageSignal.set('Error de conexión');
    errorCodeSignal.set('NETWORK_ERROR');

    comp.solicitarEvaluacion(true);
    expect(mockAsistenciaService.evaluar).toHaveBeenCalledWith(true);
  });

  it('Rol MEDICO opera en modo auditoría: puedeEvaluar es false y puede buscar historial por idPaciente', () => {
    isPacienteSignal.set(false);
    isDoctorSignal.set(true);
    hasPermissionMock.mockImplementation((perm) => perm === 'assistance:read');

    const comp = createComponent();
    expect(comp.esDoctor()).toBe(true);
    expect(comp.esPaciente()).toBe(false);
    expect(comp.puedeEvaluar()).toBe(false);

    // El médico no evalúa bajo demanda
    comp.solicitarEvaluacion();
    expect(mockAsistenciaService.evaluar).not.toHaveBeenCalled();

    // El médico ingresa un ID de paciente y busca
    comp.idPacienteMedico.set(42);
    comp.buscarHistorialMedico();
    expect(mockAsistenciaService.getHistorial).toHaveBeenCalledWith(1, 10, 42);
  });

  it('Paginación avanza y retrocede dentro de los rangos válidos', () => {
    const comp = createComponent();
    historialSignal.set(historialMock);
    comp.paginaHistorial.set(1);

    // Avanza a página 2
    comp.paginaSiguiente();
    expect(comp.paginaHistorial()).toBe(2);
    expect(mockAsistenciaService.getHistorial).toHaveBeenCalledWith(2, 10, undefined);

    // En página 2, no debe avanzar más allá de total_paginas (2)
    comp.paginaSiguiente();
    expect(comp.paginaHistorial()).toBe(2);

    // Retrocede a página 1
    comp.paginaAnterior();
    expect(comp.paginaHistorial()).toBe(1);

    // En página 1, no debe retroceder más
    comp.paginaAnterior();
    expect(comp.paginaHistorial()).toBe(1);
  });

  it('Modal de detalle histórico: abre, carga por id y limpia al cerrar', () => {
    const comp = createComponent();
    expect(comp.modalDetalleAbierto()).toBe(false);

    comp.verDetalle(50);
    expect(comp.modalDetalleAbierto()).toBe(true);
    expect(mockAsistenciaService.getEvaluacionById).toHaveBeenCalledWith(50);

    comp.cerrarModalDetalle();
    expect(comp.modalDetalleAbierto()).toBe(false);
    expect(mockAsistenciaService.limpiarDetalle).toHaveBeenCalled();
  });
});

