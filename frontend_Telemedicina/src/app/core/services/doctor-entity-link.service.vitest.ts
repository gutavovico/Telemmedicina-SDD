import { describe, expect, it } from 'vitest';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideHttpClient } from '@angular/common/http';
import { TestBed } from '@angular/core/testing';
import { DoctorEntityLinkService } from './doctor-entity-link.service';

const BASE = 'http://localhost:8000/api/v1/medicos/vinculaciones';

describe('CU29 DoctorEntityLinkService', () => {
  function setup(): { service: DoctorEntityLinkService; http: HttpTestingController } {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    return {
      service: TestBed.inject(DoctorEntityLinkService),
      http: TestBed.inject(HttpTestingController),
    };
  }

  it('busca candidatos con criterio y valor exactos', () => {
    const { service, http } = setup();
    service.buscarCandidato('correo', ' medico@clinica.test ').subscribe();
    const request = http.expectOne(
      (candidate) => candidate.url === `${BASE}/candidatos` && candidate.params.get('criterio') === 'correo' && candidate.params.get('valor') === 'medico@clinica.test',
    );
    expect(request.request.method).toBe('GET');
    request.flush({});
  });

  it('crea vínculos con asignaciones y sedes vacías', () => {
    const { service, http } = setup();
    service.crearVinculacion({
      modo: 'NUEVO',
      usuario: { nombres: 'Ada', apellidos: 'Lovelace', correo: 'ada@test.com' },
      asignaciones: { roles: [2], id_rol_principal: 2, especialidades: [], sedes: [] },
    }).subscribe();
    const request = http.expectOne(`${BASE}`);
    expect(request.request.method).toBe('POST');
    expect(request.request.body.asignaciones.sedes).toEqual([]);
    request.flush({});
  });

  it('envía paginación, estado y búsqueda al listado administrativo', () => {
    const { service, http } = setup();
    service.listarVinculaciones({ page: 2, per_page: 10, estado: 'ACTIVO', q: 'Ada' }).subscribe();
    const request = http.expectOne((item) => item.url === BASE);
    expect(request.request.params.get('page')).toBe('2');
    expect(request.request.params.get('per_page')).toBe('10');
    expect(request.request.params.get('estado')).toBe('ACTIVO');
    expect(request.request.params.get('q')).toBe('Ada');
    request.flush({});
  });

  it('incluye row_version al reemplazar asignaciones', () => {
    const { service, http } = setup();
    service.reemplazarAsignaciones(9, {
      roles: [2], id_rol_principal: 2, especialidades: [], sedes: [], row_version: 7,
    }).subscribe();
    const request = http.expectOne(`${BASE}/9/asignaciones`);
    expect(request.request.method).toBe('PUT');
    expect(request.request.body.row_version).toBe(7);
    request.flush({});
  });

  it('incluye row_version al cambiar el estado', () => {
    const { service, http } = setup();
    service.cambiarEstado(9, { estado: 'SUSPENDIDO', motivo: 'Solicitud', row_version: 4 }).subscribe();
    const request = http.expectOne(`${BASE}/9/estado`);
    expect(request.request.method).toBe('PATCH');
    expect(request.request.body.row_version).toBe(4);
    request.flush({});
  });

  it('lista las entidades activas del médico para el selector', () => {
    const { service, http } = setup();
    service.listarMisEntidades().subscribe();
    const request = http.expectOne(`${BASE}/mias/entidades`);
    expect(request.request.method).toBe('GET');
    request.flush({ items: [] });
  });

  it('acepta y rechaza invitaciones con los endpoints contractuales', () => {
    const { service, http } = setup();
    service.aceptarInvitacion(11).subscribe();
    const accept = http.expectOne(`${BASE}/11/aceptar`);
    expect(accept.request.method).toBe('POST');
    accept.flush({});

    service.rechazarInvitacion(12, { motivo: 'No corresponde' }).subscribe();
    const reject = http.expectOne(`${BASE}/12/rechazar`);
    expect(reject.request.method).toBe('POST');
    expect(reject.request.body).toEqual({ motivo: 'No corresponde' });
    reject.flush({});
  });

  it('filtra la bandeja médica por estado', () => {
    const { service, http } = setup();
    service.listarMisVinculaciones({ page: 1, per_page: 20, estado: 'INVITADO' }).subscribe();
    const request = http.expectOne((item) => item.url === `${BASE}/mias`);
    expect(request.request.params.get('estado')).toBe('INVITADO');
    request.flush({});
  });
});
