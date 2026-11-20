import { HttpClient, HttpErrorResponse, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable, from, map, switchMap, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { environment } from '../../../../../../environments/environment';
import {
  AnularResultadoRequest,
  ArchivoDescargado,
  CargaManualDatos,
  ResolverPendienteRequest,
  ResultadoLaboratorio,
  ResultadoLaboratorioListResponse,
  ResultadoLaboratorioQueryParams,
} from '../models/laboratory-result.models';
import { normalizarErrorConBlob } from '../utils/laboratory-result-errors';
import { nombreDesdeContentDisposition } from '../utils/laboratory-result-file';

/**
 * Cliente HTTP de resultados de laboratorio (CU11). Rutas del contrato `resultados-laboratorio.md`.
 * `Authorization` y `X-Tenant-ID` los agregan los interceptores; nunca se envían `id_clinica`, `tenant_id`,
 * `estado` ni `origen` en el cuerpo de las peticiones.
 */
@Injectable({ providedIn: 'root' })
export class LaboratoryResultsService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${environment.apiUrl}/api/v1/resultados-laboratorio`;

  private construirParametros(params: ResultadoLaboratorioQueryParams = {}): HttpParams {
    let http = new HttpParams()
      .set('page', String(params.page ?? 1))
      .set('page_size', String(params.page_size ?? 10));
    if (params.id_paciente != null) http = http.set('id_paciente', String(params.id_paciente));
    if (params.id_fuente != null) http = http.set('id_fuente', String(params.id_fuente));
    if (params.codigo_examen?.trim()) http = http.set('codigo_examen', params.codigo_examen.trim());
    if (params.laboratorio_origen?.trim()) http = http.set('laboratorio_origen', params.laboratorio_origen.trim());
    if (params.origen) http = http.set('origen', params.origen);
    if (params.estado) http = http.set('estado', params.estado);
    if (params.fecha_desde) http = http.set('fecha_desde', params.fecha_desde);
    if (params.fecha_hasta) http = http.set('fecha_hasta', params.fecha_hasta);
    return http;
  }

  /** `GET /api/v1/resultados-laboratorio` (3.2). Por defecto solo INCORPORADO. */
  listar(params: ResultadoLaboratorioQueryParams = {}): Observable<ResultadoLaboratorioListResponse> {
    return this.http.get<ResultadoLaboratorioListResponse>(this.baseUrl, { params: this.construirParametros(params) });
  }

  /** `GET /api/v1/pacientes/{id_paciente}/resultados-laboratorio` (3.3): expediente del paciente. */
  listarDePaciente(
    idPaciente: number,
    params: ResultadoLaboratorioQueryParams = {},
  ): Observable<ResultadoLaboratorioListResponse> {
    const { id_paciente: _omitido, estado: _estado, id_fuente: _fuente, ...resto } = params;
    return this.http.get<ResultadoLaboratorioListResponse>(
      `${environment.apiUrl}/api/v1/pacientes/${idPaciente}/resultados-laboratorio`,
      { params: this.construirParametros(resto) },
    );
  }

  /** `GET /api/v1/resultados-laboratorio/me` (3.4): resultados del paciente autenticado. */
  listarPropios(params: ResultadoLaboratorioQueryParams = {}): Observable<ResultadoLaboratorioListResponse> {
    const { id_paciente: _omitido, estado: _estado, id_fuente: _fuente, origen: _origen, laboratorio_origen: _lab, ...resto } = params;
    return this.http.get<ResultadoLaboratorioListResponse>(`${this.baseUrl}/me`, {
      params: this.construirParametros(resto),
    });
  }

  /** `GET /api/v1/resultados-laboratorio/{id}` (3.5). */
  obtener(idResultado: number): Observable<ResultadoLaboratorio> {
    return this.http.get<ResultadoLaboratorio>(`${this.baseUrl}/${idResultado}`);
  }

  /**
   * `POST /api/v1/resultados-laboratorio` (3.1), `multipart/form-data`. No se fija `Content-Type`: el
   * navegador agrega el `boundary`.
   */
  cargarManual(datos: CargaManualDatos): Observable<ResultadoLaboratorio> {
    const formulario = new FormData();
    formulario.append('archivo', datos.archivo, datos.archivo.name);
    formulario.append('id_paciente', String(datos.id_paciente));
    formulario.append('codigo_examen', datos.codigo_examen.trim());
    formulario.append('fecha_realizacion', datos.fecha_realizacion);
    formulario.append('laboratorio_origen', datos.laboratorio_origen.trim());
    if (datos.id_orden != null) formulario.append('id_orden', String(datos.id_orden));
    const observaciones = datos.observaciones?.trim();
    if (observaciones) formulario.append('observaciones', observaciones);
    return this.http.post<ResultadoLaboratorio>(this.baseUrl, formulario);
  }

  /**
   * `GET /api/v1/resultados-laboratorio/{id}/archivo` (3.6). El endpoint exige Bearer, por eso se descarga
   * como `Blob` (no como enlace directo). Usa el `Content-Type` real devuelto por el servidor.
   */
  descargar(idResultado: number): Observable<ArchivoDescargado> {
    return this.http
      .get(`${this.baseUrl}/${idResultado}/archivo`, { responseType: 'blob', observe: 'response' })
      .pipe(
        map((respuesta) => {
          const blob = respuesta.body as Blob;
          const contentType = respuesta.headers.get('Content-Type')?.split(';')[0].trim() || blob.type;
          const nombre = nombreDesdeContentDisposition(
            respuesta.headers.get('Content-Disposition'),
            `resultado-${idResultado}`,
          );
          return { blob, contentType, nombre };
        }),
        catchError((error: unknown) =>
          error instanceof HttpErrorResponse
            ? from(normalizarErrorConBlob(error)).pipe(switchMap((normalizado) => throwError(() => normalizado)))
            : throwError(() => error),
        ),
      );
  }

  /** `POST /api/v1/resultados-laboratorio/{id}/resolver` (3.7). */
  resolver(idResultado: number, solicitud: ResolverPendienteRequest): Observable<ResultadoLaboratorio> {
    return this.http.post<ResultadoLaboratorio>(`${this.baseUrl}/${idResultado}/resolver`, solicitud);
  }

  /** `POST /api/v1/resultados-laboratorio/{id}/anular` (3.8). */
  anular(idResultado: number, solicitud: AnularResultadoRequest): Observable<ResultadoLaboratorio> {
    return this.http.post<ResultadoLaboratorio>(`${this.baseUrl}/${idResultado}/anular`, solicitud);
  }
}
