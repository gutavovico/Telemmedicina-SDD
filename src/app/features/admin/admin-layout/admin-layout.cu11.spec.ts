import { signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { describe, expect, it } from 'vitest';
import { AuthService } from '../../../core/services/auth.service';
import { TenantService } from '../../../core/services/tenant.service';
import { AdminLayout } from './admin-layout';

describe('AdminLayout · acceso al menú de Resultados de Laboratorio (CU11)', () => {
  function crear(permisos: string[], esSuperAdmin = false) {
    const permisosSignal = signal(permisos);
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: AuthService, useValue: { currentUser: signal(null), isAuthenticated: signal(true), profileVerified: signal(true) } },
        { provide: TenantService, useValue: { currentTenant: signal(null), permisos: permisosSignal, isSuperAdmin: () => esSuperAdmin } },
      ],
    });
    const fixture = TestBed.createComponent(AdminLayout);
    return { layout: fixture.componentInstance, permisosSignal, fixture };
  }

  it('muestra el menú solo con lab_results:read, igual que PermissionsService.hasPermission', () => {
    const { layout, permisosSignal, fixture } = crear(['documents:search']);
    expect(layout.puedeVerResultadosLaboratorio()).toBe(false);
    permisosSignal.set(['documents:search', 'lab_results:read']);
    expect(layout.puedeVerResultadosLaboratorio()).toBe(true);
    fixture.destroy();
  });

  it('un permiso parecido no habilita el menú', () => {
    const { layout, fixture } = crear(['lab_results:create', 'documents:read:lab_results', 'lab_orders:read']);
    expect(layout.puedeVerResultadosLaboratorio()).toBe(false);
    fixture.destroy();
  });

  it('el superadministrador lo ve (mismo criterio global del servicio de permisos)', () => {
    const { layout, fixture } = crear([], true);
    expect(layout.puedeVerResultadosLaboratorio()).toBe(true);
    fixture.destroy();
  });
});
