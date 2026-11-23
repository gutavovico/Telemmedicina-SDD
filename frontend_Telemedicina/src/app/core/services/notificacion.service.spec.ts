import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { signal } from '@angular/core';
import { NotificacionService } from './notificacion.service';
import { AuthService } from './auth.service';
import { NotificacionDTO } from '../models/notificacion.models';

describe('NotificacionService (CU20)', () => {
  let service: NotificacionService;
  let httpMock: HttpTestingController;
  let mockRole: ReturnType<typeof signal<string>>;

  beforeEach(() => {
    mockRole = signal<string>('PACIENTE');
    const authMock = {
      isAuthenticated: signal(true),
      currentUser: () => ({ id_usuario: 10, rol: mockRole(), estado: 'ACTIVO' }),
    };

    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        NotificacionService,
        { provide: AuthService, useValue: authMock },
      ],
    });

    service = TestBed.inject(NotificacionService);
    httpMock = TestBed.inject(HttpTestingController);
    TestBed.flushEffects();

    // Limpiar la llamada inicial del effect (resumen-no-leidas)
    const initReqs = httpMock.match((r) => r.url.includes('/notificaciones/resumen-no-leidas'));
    initReqs.forEach((req) => req.flush({ no_leidas: 2, total: 5, por_categoria: { CITAS: 2 } }));
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('debe actualizar el conteo de no leídas desde el resumen', () => {
    expect(service.conteoNoLeidas()).toBe(2);
    expect(service.totalNotificaciones()).toBe(5);
  });

  it('debe resolver deep links según el rol (Paciente vs Médico vs Admin)', () => {
    const salaNotif: NotificacionDTO = {
      id_notificacion: 1,
      id_usuario: 10,
      tipo: 'SALA_VIRTUAL_ABIERTA',
      categoria: 'CITAS',
      recurso_tipo: 'SALA_VIRTUAL',
      recurso_id: '42',
      estado: 'ENVIADO',
      created_at: new Date().toISOString(),
    };

    mockRole.set('PACIENTE');
    expect(service.resolverRutaDestino(salaNotif)).toBe('/citas/42/teleconsulta');

    mockRole.set('MEDICO');
    expect(service.resolverRutaDestino(salaNotif)).toBe('/admin/teleconsulta/42');

    const backupNotif: NotificacionDTO = {
      id_notificacion: 2,
      id_usuario: 1,
      tipo: 'BACKUP',
      categoria: 'SISTEMA',
      recurso_tipo: 'BACKUP',
      estado: 'ENVIADO',
      created_at: new Date().toISOString(),
    };
    mockRole.set('ADMIN');
    expect(service.resolverRutaDestino(backupNotif)).toBe('/admin/backups');
  });

  it('debe marcar todas como leídas y resetear el contador a 0', () => {
    service.marcarTodasLeidas().subscribe((res) => {
      expect(res.actualizadas).toBe(2);
    });

    const req = httpMock.expectOne((r) =>
      r.url.includes('/api/v1/notificaciones/bandeja/marcar-todas-leidas'),
    );
    expect(req.request.method).toBe('POST');
    req.flush({ actualizadas: 2 });

    expect(service.conteoNoLeidas()).toBe(0);
  });
});
