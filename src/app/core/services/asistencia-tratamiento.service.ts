import { Injectable, inject, signal } from '@angular/core';
import { HttpClient, HttpErrorResponse, HttpParams } from '@angular/common/http';
import { Observable, catchError, finalize, tap, throwError } from 'rxjs';
import { environment } from '../../../environments/environment';
import {
  EvaluacionTratamientoResponse,
  EvaluarTratamientoRequest,
  HistorialEvaluacionResponse,
  CatalogoInteraccionesResponse,
} from '../models/asistencia-tratamiento.models';

/**
 * Servicio Angular para el Asistente Inteligente de Tratamiento (CU18).
 *
 * Se comunica con el backend mediante /api/v1/asistencia-tratamiento.
 * La autenticación (Bearer JWT) y el inquilino (id_clinica) se inyectan
 * automáticamente a través de los interceptores HTTP configurados.
 */
@Injectable({
  providedIn: 'root',
})
export class AsistenciaTratamientoService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${environment.apiUrl}/api/v1/asistencia-tratamiento`;

  // Signals reactivos de estado
  readonly evaluacionActual = signal<EvaluacionTratamientoResponse | null>(null);
  readonly isLoading = signal<boolean>(false);
  readonly errorMessage = signal<string | null>(null);
  readonly errorCode = signal<string | null>(null);
  readonly retryAfterSeconds = signal<number | null>(null);

  // Historial paginado
  readonly historial = signal<HistorialEvaluacionResponse | null>(null);
  readonly isLoadingHistorial = signal<boolean>(false);
  readonly historialError = signal<string | null>(null);

  // Detalle seleccionado
  readonly selectedDetalle = signal<EvaluacionTratamientoResponse | null>(null);
  readonly isLoadingDetalle = signal<boolean>(false);
  readonly detalleError = signal<string | null>(null);

  /**
   * Solicita evaluación asistida bajo demanda del tratamiento activo.
   */
  evaluar(forzarRecalculo: boolean = false): Observable<EvaluacionTratamientoResponse> {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    this.errorCode.set(null);
    this.retryAfterSeconds.set(null);

    const body: EvaluarTratamientoRequest = { forzar_recalculo: forzarRecalculo };

    return this.http.post<EvaluacionTratamientoResponse>(`${this.baseUrl}/evaluar`, body).pipe(
      tap((response) => {
        this.evaluacionActual.set(response);
      }),
      catchError((error: HttpErrorResponse) => {
        this.handleEvaluationError(error);
        return throwError(() => error);
      }),
      finalize(() => {
        this.isLoading.set(false);
      })
    );
  }

  /**
   * Obtiene el historial paginado de evaluaciones.
   * Si es médico, puede consultar las evaluaciones de un paciente específico pasando `idPaciente`.
   */
  getHistorial(
    page: number = 1,
    limit: number = 10,
    idPaciente?: number
  ): Observable<HistorialEvaluacionResponse> {
    this.isLoadingHistorial.set(true);
    this.historialError.set(null);

    // Límite máximo según backend: 50
    const safeLimit = Math.min(Math.max(limit, 1), 50);
    const safePage = Math.max(page, 1);

    let params = new HttpParams()
      .set('page', safePage.toString())
      .set('limit', safeLimit.toString());

    if (idPaciente !== undefined && idPaciente !== null) {
      params = params.set('id_paciente', idPaciente.toString());
    }

    return this.http.get<HistorialEvaluacionResponse>(`${this.baseUrl}/historial`, { params }).pipe(
      tap((res) => {
        this.historial.set(res);
      }),
      catchError((error: HttpErrorResponse) => {
        const msg = error.error?.detail || 'Error al consultar el historial de evaluaciones.';
        this.historialError.set(msg);
        return throwError(() => error);
      }),
      finalize(() => {
        this.isLoadingHistorial.set(false);
      })
    );
  }

  /**
   * Obtiene el detalle completo de una evaluación por su identificador.
   */
  getEvaluacionById(idEvaluacion: number): Observable<EvaluacionTratamientoResponse> {
    this.isLoadingDetalle.set(true);
    this.detalleError.set(null);
    this.selectedDetalle.set(null);

    return this.http
      .get<EvaluacionTratamientoResponse>(`${this.baseUrl}/evaluaciones/${idEvaluacion}`)
      .pipe(
        tap((res) => {
          this.selectedDetalle.set(res);
        }),
        catchError((error: HttpErrorResponse) => {
          const msg = error.error?.detail || 'Error al consultar el detalle de la evaluación.';
          this.detalleError.set(msg);
          return throwError(() => error);
        }),
        finalize(() => {
          this.isLoadingDetalle.set(false);
        })
      );
  }

  /**
   * Consulta referencial del catálogo de interacciones farmacológicas.
   */
  getCatalogoInteracciones(
    page: number = 1,
    limit: number = 20,
    principioActivo?: string,
    severidad?: string
  ): Observable<CatalogoInteraccionesResponse> {
    let params = new HttpParams()
      .set('page', Math.max(page, 1).toString())
      .set('limit', Math.min(Math.max(limit, 1), 100).toString());

    if (principioActivo && principioActivo.trim()) {
      params = params.set('principio_activo', principioActivo.trim());
    }
    if (severidad && severidad.trim()) {
      params = params.set('severidad', severidad.trim());
    }

    return this.http.get<CatalogoInteraccionesResponse>(`${this.baseUrl}/interacciones/catalogo`, {
      params,
    });
  }

  limpiarDetalle(): void {
    this.selectedDetalle.set(null);
    this.detalleError.set(null);
  }

  private handleEvaluationError(error: HttpErrorResponse): void {
    if (error.status === 429) {
      this.errorCode.set('RATE_LIMIT_EXCEEDED');
      const retryHeader = error.headers?.get('Retry-After');
      const parsedSeconds = retryHeader ? parseInt(retryHeader, 10) : 3600;
      this.retryAfterSeconds.set(isNaN(parsedSeconds) ? 3600 : parsedSeconds);
      this.errorMessage.set(
        error.error?.detail ||
          'Has alcanzado el límite de 10 evaluaciones por hora. Por favor intenta más tarde.'
      );
      return;
    }

    if (error.status === 403) {
      this.errorCode.set('PERMISSION_DENIED');
      this.errorMessage.set(
        error.error?.detail || 'No tienes permisos para evaluar el tratamiento.'
      );
      return;
    }

    if (error.status === 404) {
      this.errorCode.set('PATIENT_NOT_FOUND');
      this.errorMessage.set(
        error.error?.detail || 'El paciente no fue encontrado en la clínica activa.'
      );
      return;
    }

    if (error.status === 0) {
      this.errorCode.set('NETWORK_ERROR');
      this.errorMessage.set(
        'No se pudo conectar con el servidor. Verifica tu conexión a internet.'
      );
      return;
    }

    this.errorCode.set(error.error?.code || 'UNKNOWN_ERROR');
    this.errorMessage.set(
      error.error?.detail || 'Ocurrió un error inesperado al procesar la asistencia inteligente.'
    );
  }
}

