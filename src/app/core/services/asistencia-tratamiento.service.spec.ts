import { HttpErrorResponse, HttpHeaders, provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { environment } from '../../../environments/environment';
import { AsistenciaTratamientoService } from './asistencia-tratamiento.service';
import {
  EvaluacionTratamientoResponse,
  HistorialEvaluacionResponse,
} from '../models/asistencia-tratamiento.models';

describe('AsistenciaTratamientoService (CU18)', () => {
  let service: AsistenciaTratamientoService;
  let http: HttpTestingController;
  const baseUrl = `${environment.apiUrl}/api/v1/asistencia-tratamiento`;

  const evaluacionMock: EvaluacionTratamientoResponse = {
    id_evaluacion: 101,
    id_paciente: 1,
    fecha_evaluacion: '2026-11-04T12:00:00Z',
    estado_evaluacion: 'COMPLETADA',
    nivel_riesgo_global: 'ALTO',
    total_medicamentos_analizados: 2,
    total_alertas_detectadas: 1,
    resumen_ejecutivo: 'Interacción detectada entre antiinflamatorios',
    aviso_legal: 'Sugerencias de apoyo. La IA nunca modifica diagnósticos, dosis ni tratamientos.',
    medicamentos_analizados: [
      { nombre: 'Ibuprofeno', principio_activo: 'Ibuprofeno', dosis: '400mg', frecuencia: 'Cada 8 horas' },
      { nombre: 'Aspirina', principio_activo: 'Ácido acetilsalicílico', dosis: '100mg', frecuencia: 'Cada 24 horas' },
    ],
    alertas: [
      {
        id_alerta: 1,
        principio_activo_1: 'Ibuprofeno',
        principio_activo_2: 'Ácido acetilsalicílico',
        medicamento_1_nombre: 'Ibuprofeno',
        medicamento_2_nombre: 'Aspirina',
        severidad: 'GRAVE',
        color_alerta: 'ROJO',
        mensaje_alerta: 'Riesgo de interacción: aumento de riesgo de sangrado gastrointestinal.',
        pauta_precaucion: 'Consulte a su médico de inmediato antes de continuar administrando ambos medicamentos.',
      },
    ],
    recomendaciones: [
      {
        id_recomendacion: 1,
        categoria: 'SIGNOS_ALARMA',
        titulo: 'Signos de sangrado',
        detalle: 'Vigile la presencia de heces oscuras o mareos anormales.',
        origen: 'IA_GENERATIVA',
      },
    ],
  };

  const historialMock: HistorialEvaluacionResponse = {
    items: [
      {
        id_evaluacion: 101,
        id_paciente: 1,
        fecha_evaluacion: '2026-11-04T12:00:00Z',
        estado_evaluacion: 'COMPLETADA',
        nivel_riesgo_global: 'ALTO',
        total_medicamentos_analizados: 2,
        total_alertas_detectadas: 1,
        resumen_ejecutivo: 'Interacción detectada',
      },
    ],
    total: 1,
    page: 1,
    limit: 10,
    total_paginas: 1,
  };

  beforeEach(() => {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting(), AsistenciaTratamientoService],
    });
    service = TestBed.inject(AsistenciaTratamientoService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    if (http) {
      http.verify();
    }
    TestBed.resetTestingModule();
  });

  it('evaluar() realiza POST a /evaluar y actualiza signal evaluacionActual', () => {
    service.evaluar(false).subscribe((res) => {
      expect(res.id_evaluacion).toBe(101);
      expect(res.nivel_riesgo_global).toBe('ALTO');
    });

    const req = http.expectOne(`${baseUrl}/evaluar`);
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual({ forzar_recalculo: false });
    req.flush(evaluacionMock);

    expect(service.evaluacionActual()).toEqual(evaluacionMock);
    expect(service.isLoading()).toBe(false);
    expect(service.errorMessage()).toBeNull();
  });

  it('evaluar() maneja error 429 con Retry-After y código RATE_LIMIT_EXCEEDED', () => {
    service.evaluar(false).subscribe({
      next: () => expect.unreachable('Debe fallar con 429'),
      error: () => {},
    });

    const headers = new HttpHeaders({ 'Retry-After': '3600' });
    const req = http.expectOne(`${baseUrl}/evaluar`);
    req.flush(
      { detail: 'Has alcanzado el límite de 10 evaluaciones por hora.', code: 'RATE_LIMIT_EXCEEDED' },
      { status: 429, statusText: 'Too Many Requests', headers }
    );

    expect(service.errorCode()).toBe('RATE_LIMIT_EXCEEDED');
    expect(service.retryAfterSeconds()).toBe(3600);
    expect(service.errorMessage()).toContain('límite de 10 evaluaciones');
    expect(service.isLoading()).toBe(false);
  });

  it('evaluar() mapea 403 Forbidden y 404 Not Found correctamente', () => {
    service.evaluar(false).subscribe({
      next: () => expect.unreachable('Debe fallar con 403'),
      error: () => {},
    });

    const req403 = http.expectOne(`${baseUrl}/evaluar`);
    req403.flush({ detail: 'No tienes permisos' }, { status: 403, statusText: 'Forbidden' });
    expect(service.errorCode()).toBe('PERMISSION_DENIED');

    service.evaluar(false).subscribe({
      next: () => expect.unreachable('Debe fallar con 404'),
      error: () => {},
    });

    const req404 = http.expectOne(`${baseUrl}/evaluar`);
    req404.flush({ detail: 'Paciente no encontrado' }, { status: 404, statusText: 'Not Found' });
    expect(service.errorCode()).toBe('PATIENT_NOT_FOUND');
  });

  it('evaluar() maneja error de red (status 0)', () => {
    service.evaluar(false).subscribe({
      next: () => expect.unreachable('Debe fallar con status 0'),
      error: () => {},
    });

    const req = http.expectOne(`${baseUrl}/evaluar`);
    req.error(new ProgressEvent('Network error'), { status: 0 });
    expect(service.errorCode()).toBe('NETWORK_ERROR');
    expect(service.errorMessage()).toContain('conexión');
  });

  it('getHistorial() consulta /historial con límite seguro y actualiza signal historial', () => {
    service.getHistorial(1, 10).subscribe((res) => {
      expect(res.total).toBe(1);
      expect(res.items.length).toBe(1);
    });

    const req = http.expectOne(`${baseUrl}/historial?page=1&limit=10`);
    expect(req.request.method).toBe('GET');
    req.flush(historialMock);

    expect(service.historial()).toEqual(historialMock);
    expect(service.isLoadingHistorial()).toBe(false);
  });

  it('getHistorial() incluye id_paciente para médicos y aplica límites máximos (50)', () => {
    service.getHistorial(2, 999, 45).subscribe();

    const req = http.expectOne(`${baseUrl}/historial?page=2&limit=50&id_paciente=45`);
    expect(req.request.method).toBe('GET');
    req.flush(historialMock);
  });

  it('getEvaluacionById() consulta detalle y limpia estado con limpiarDetalle()', () => {
    service.getEvaluacionById(101).subscribe((res) => {
      expect(res.id_evaluacion).toBe(101);
    });

    const req = http.expectOne(`${baseUrl}/evaluaciones/101`);
    expect(req.request.method).toBe('GET');
    req.flush(evaluacionMock);

    expect(service.selectedDetalle()).toEqual(evaluacionMock);

    service.limpiarDetalle();
    expect(service.selectedDetalle()).toBeNull();
  });
});

