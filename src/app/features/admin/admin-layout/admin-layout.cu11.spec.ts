import { Injector, runInInjectionContext, signal } from '@angular/core';
import { Router } from '@angular/router';
import { describe, expect, it, vi } from 'vitest';
import { AuthService } from '../../../core/services/auth.service';
import { TenantService } from '../../../core/services/tenant.service';
import { AdminLayout } from './admin-layout';

describe('AdminLayout · acceso al menú de Resultados de Laboratorio (CU11)', () => {
  function crear(permisos: string[], esSuperAdmin = false) {
    const permisosSignal = signal(permisos);
    const injector = Injector.create({
      providers: [
        { provide: AuthService, useValue: { currentUser: signal(null), isAuthenticated: signal(true), profileVerified: signal(true) } },
        { provide: TenantService, useValue: { permisos: permisosSignal, isSuperAdmin: () => esSuperAdmin } },
        { provide: Router, useValue: { navigate: vi.fn() } },
      ],
    });
    const layout = runInInjectionContext(injector, () => new AdminLayout());
    return { layout, permisosSignal, injector };
  }

  it('muestra el menú solo con lab_results:read, igual que PermissionsService.hasPermission', () => {
    const { layout, permisosSignal, injector } = crear(['documents:search']);
    expect(layout.puedeVerResultadosLaboratorio()).toBe(false);
    permisosSignal.set(['documents:search', 'lab_results:read']);
    expect(layout.puedeVerResultadosLaboratorio()).toBe(true);
    injector.destroy();
  });

  it('un permiso parecido no habilita el menú', () => {
    const { layout, injector } = crear(['lab_results:create', 'documents:read:lab_results', 'lab_orders:read']);
    expect(layout.puedeVerResultadosLaboratorio()).toBe(false);
    injector.destroy();
  });

  it('el superadministrador lo ve (mismo criterio global del servicio de permisos)', () => {
    const { layout, injector } = crear([], true);
    expect(layout.puedeVerResultadosLaboratorio()).toBe(true);
    injector.destroy();
  });
});
