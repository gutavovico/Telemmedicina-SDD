import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import {
  DoctorEntityCandidate,
  DoctorEntityLinkCreate,
  DoctorEntityLinkCreateResponse,
  DoctorEntityLinkDetailResponse,
  DoctorEntityLinkFilters,
  DoctorEntityLink,
  DoctorEntityLinkListResponse,
  DoctorEntityLinkState,
  DoctorEntityMineFilters,
  DoctorEntityRejection,
  DoctorEntitySearchCriterion,
  DoctorEntityStateUpdate,
  DoctorEntityAssignmentsUpdate,
  DoctorEntityAvailableClinicsResponse,
} from '../models/doctor-entity-link.models';

@Injectable({ providedIn: 'root' })
export class DoctorEntityLinkService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${environment.apiUrl}/api/v1/medicos/vinculaciones`;

  buscarCandidato(
    criterio: DoctorEntitySearchCriterion,
    valor: string,
  ): Observable<DoctorEntityCandidate> {
    const params = new HttpParams().set('criterio', criterio).set('valor', valor.trim());
    return this.http.get<DoctorEntityCandidate>(`${this.baseUrl}/candidatos`, { params });
  }

  crearVinculacion(
    datos: DoctorEntityLinkCreate,
  ): Observable<DoctorEntityLinkCreateResponse> {
    return this.http.post<DoctorEntityLinkCreateResponse>(this.baseUrl, datos);
  }

  listarVinculaciones(
    filtros: DoctorEntityLinkFilters = {},
  ): Observable<DoctorEntityLinkListResponse> {
    return this.http.get<DoctorEntityLinkListResponse>(this.baseUrl, {
      params: this.buildLinkParams(filtros),
    });
  }

  obtenerDetalle(idVinculacion: number): Observable<DoctorEntityLinkDetailResponse> {
    return this.http.get<DoctorEntityLinkDetailResponse>(
      `${this.baseUrl}/${idVinculacion}`,
    );
  }

  reemplazarAsignaciones(
    idVinculacion: number,
    datos: DoctorEntityAssignmentsUpdate,
  ): Observable<DoctorEntityLink> {
    return this.http.put<DoctorEntityLink>(
      `${this.baseUrl}/${idVinculacion}/asignaciones`,
      datos,
    );
  }

  cambiarEstado(
    idVinculacion: number,
    datos: DoctorEntityStateUpdate,
  ): Observable<DoctorEntityLink> {
    return this.http.patch<DoctorEntityLink>(
      `${this.baseUrl}/${idVinculacion}/estado`,
      datos,
    );
  }

  listarMisVinculaciones(
    filtros: DoctorEntityMineFilters = {},
  ): Observable<DoctorEntityLinkListResponse> {
    let params = new HttpParams();
    if (filtros.page !== undefined) {
      params = params.set('page', filtros.page.toString());
    }
    if (filtros.per_page !== undefined) {
      params = params.set('per_page', filtros.per_page.toString());
    }
    if (filtros.estado) {
      params = params.set('estado', filtros.estado);
    }
    return this.http.get<DoctorEntityLinkListResponse>(`${this.baseUrl}/mias`, {
      params,
    });
  }

  listarMisEntidades(): Observable<DoctorEntityAvailableClinicsResponse> {
    return this.http.get<DoctorEntityAvailableClinicsResponse>(
      `${this.baseUrl}/mias/entidades`,
    );
  }

  aceptarInvitacion(idVinculacion: number): Observable<DoctorEntityLink> {
    return this.http.post<DoctorEntityLink>(
      `${this.baseUrl}/${idVinculacion}/aceptar`,
      null,
    );
  }

  rechazarInvitacion(
    idVinculacion: number,
    datos: DoctorEntityRejection,
  ): Observable<DoctorEntityLink> {
    return this.http.post<DoctorEntityLink>(
      `${this.baseUrl}/${idVinculacion}/rechazar`,
      datos,
    );
  }

  private buildLinkParams(filtros: DoctorEntityLinkFilters): HttpParams {
    let params = new HttpParams();
    if (filtros.page !== undefined) {
      params = params.set('page', filtros.page.toString());
    }
    if (filtros.per_page !== undefined) {
      params = params.set('per_page', filtros.per_page.toString());
    }
    if (filtros.estado) {
      params = params.set('estado', filtros.estado);
    }
    const q = filtros.q?.trim();
    if (q) {
      params = params.set('q', q);
    }
    return params;
  }
}

export type { DoctorEntityLinkState };
