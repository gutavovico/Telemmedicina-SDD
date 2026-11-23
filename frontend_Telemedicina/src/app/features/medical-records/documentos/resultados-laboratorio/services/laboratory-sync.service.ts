import { HttpClient, HttpEvent, HttpEventType, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable, filter, map } from 'rxjs';
import { environment } from '../../../../../../environments/environment';
import {
  EventoSubida,
  FuenteLaboratorio,
  FuenteLaboratorioCreateRequest,
  FuenteLaboratorioListResponse,
  FuenteLaboratorioQueryParams,
  FuenteLaboratorioUpdateRequest,
  Manifiesto,
  Sincronizacion,
  SincronizacionListResponse,
  SincronizacionQueryParams,
} from '../models/laboratory-sync.models';

/**
 * Cliente HTTP de fuentes y sincronización de laboratorio (CU11, bloque B). Rutas del contrato
 * `resultados-laboratorio.md` sección 4. `Authorization` y `X-Tenant-ID` los agregan los interceptores; nunca se
 * envían `id_clinica` ni `tenant_id`. Los errores no se capturan aquí: las pantallas los interpretan con
 * `interpretarErrorSincronizacion`.
 */
@Injectable({ providedIn: 'root' })
export class LaboratorySyncService {
  private readonly http = inject(HttpClient);
  private readonly urlFuentes = `${environment.apiUrl}/api/v1/fuentes-laboratorio`;
  private readonly urlSincronizaciones = `${environment.apiUrl}/api/v1/sincronizaciones-laboratorio`;

  // -------------------------------------------------------------------------
  // Fuentes (4.1 a 4.3)
  // -------------------------------------------------------------------------
  /** `GET /api/v1/fuentes-laboratorio` (4.1). */
  listarFuentes(params: FuenteLaboratorioQueryParams = {}): Observable<FuenteLaboratorioListResponse> {
    let http = new HttpParams()
      .set('page', String(params.page ?? 1))
      .set('page_size', String(params.page_size ?? 10));
    if (params.activa) http = http.set('activa', params.activa);
    return this.http.get<FuenteLaboratorioListResponse>(this.urlFuentes, { params: http });
  }

  /** `POST /api/v1/fuentes-laboratorio` (4.2). */
  crearFuente(solicitud: FuenteLaboratorioCreateRequest): Observable<FuenteLaboratorio> {
    return this.http.post<FuenteLaboratorio>(this.urlFuentes, {
      codigo: solicitud.codigo.trim(),
      nombre: solicitud.nombre.trim(),
    });
  }

  /** `PATCH /api/v1/fuentes-laboratorio/{id_fuente}` (4.3): nombre y activa; el código no se modifica. */
  actualizarFuente(idFuente: number, solicitud: FuenteLaboratorioUpdateRequest): Observable<FuenteLaboratorio> {
    return this.http.patch<FuenteLaboratorio>(`${this.urlFuentes}/${idFuente}`, solicitud);
  }

  // -------------------------------------------------------------------------
  // Sincronizaciones (4.4 a 4.7)
  // -------------------------------------------------------------------------
  /**
   * `POST /api/v1/sincronizaciones-laboratorio` (4.4), `multipart/form-data` con `manifiesto` (texto JSON) y
   * `archivos` (una parte por archivo, con su nombre). No se fija `Content-Type`: el navegador agrega el `boundary`.
   */
  importar(manifiesto: Manifiesto, archivos: readonly File[]): Observable<EventoSubida> {
    return this.subir(this.urlSincronizaciones, manifiesto, archivos);
  }

  /** `GET /api/v1/sincronizaciones-laboratorio` (4.5): historial paginado, sin `items`. */
  listarSincronizaciones(params: SincronizacionQueryParams = {}): Observable<SincronizacionListResponse> {
    let http = new HttpParams()
      .set('page', String(params.page ?? 1))
      .set('page_size', String(params.page_size ?? 10));
    if (params.id_fuente != null) http = http.set('id_fuente', String(params.id_fuente));
    if (params.estado) http = http.set('estado', params.estado);
    if (params.fecha_desde) http = http.set('fecha_desde', params.fecha_desde);
    if (params.fecha_hasta) http = http.set('fecha_hasta', params.fecha_hasta);
    return this.http.get<SincronizacionListResponse>(this.urlSincronizaciones, { params: http });
  }

  /** `GET /api/v1/sincronizaciones-laboratorio/{id_sincronizacion}` (4.6): informe con el detalle por ítem. */
  obtenerSincronizacion(idSincronizacion: number): Observable<Sincronizacion> {
    return this.http.get<Sincronizacion>(`${this.urlSincronizaciones}/${idSincronizacion}`);
  }

  /**
   * `POST /api/v1/sincronizaciones-laboratorio/{id_sincronizacion}/reintentos` (4.7): el manifiesto lleva solo los
   * ítems en `ERROR` a reintentar (con la `fuente` de la sincronización) y `archivos` los corregidos.
   */
  reintentar(idSincronizacion: number, manifiesto: Manifiesto, archivos: readonly File[]): Observable<EventoSubida> {
    return this.subir(`${this.urlSincronizaciones}/${idSincronizacion}/reintentos`, manifiesto, archivos);
  }

  private subir(url: string, manifiesto: Manifiesto, archivos: readonly File[]): Observable<EventoSubida> {
    const formulario = new FormData();
    formulario.append('manifiesto', JSON.stringify(manifiesto));
    for (const archivo of archivos) formulario.append('archivos', archivo, archivo.name);
    return this.http
      .post<Sincronizacion>(url, formulario, { observe: 'events', reportProgress: true })
      .pipe(
        filter((evento: HttpEvent<Sincronizacion>) => evento.type === HttpEventType.UploadProgress || evento.type === HttpEventType.Response),
        map((evento): EventoSubida => {
          if (evento.type === HttpEventType.UploadProgress) {
            const total = evento.total ?? null;
            return {
              tipo: 'progreso',
              porcentaje: total ? Math.min(100, Math.round((evento.loaded / total) * 100)) : null,
              cargados: evento.loaded,
              total,
            };
          }
          return { tipo: 'respuesta', sincronizacion: (evento as { body: Sincronizacion | null }).body as Sincronizacion };
        }),
      );
  }
}
