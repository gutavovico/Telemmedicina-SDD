import { TestBed } from '@angular/core/testing';
import { ActivatedRouteSnapshot, Route, Router, RouterStateSnapshot, UrlTree } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';
import { staffGuard } from './core/guards/panel-access.guard';
import { permissionsGuard } from './core/guards/permissions.guard';
import { AuthService } from './core/services/auth.service';
import { PermissionsService } from './core/services/permissions.service';
import { routes } from './app.routes';

/** CU11 (tarea 7): fuentes, importación, historial e informe de sincronizaciones exigen staff y `lab_results:sync`. */
describe('Rutas de sincronización de laboratorio (CU11, bloque B)', () => {
  const RUTAS = [
    'resultados-laboratorio/fuentes',
    'resultados-laboratorio/sincronizaciones',
    'resultados-laboratorio/sincronizaciones/importar',
    'resultados-laboratorio/sincronizaciones/:id',
  ];

  function rutasDelPanel(): Route[] {
    return routes.find((r) => r.path === 'admin')?.children ?? [];
  }

  it('declara las cuatro rutas bajo /admin, las estáticas antes que sus comodines', () => {
    const paths = rutasDelPanel().map((r) => r.path);
    for (const path of RUTAS) expect(paths).toContain(path);
    // `resultados-laboratorio/:id` tiene un solo segmento dinámico: «fuentes» y «sincronizaciones» deben ir antes.
    expect(paths.indexOf('resultados-laboratorio/fuentes')).toBeLessThan(paths.indexOf('resultados-laboratorio/:id'));
    expect(paths.indexOf('resultados-laboratorio/sincronizaciones')).toBeLessThan(paths.indexOf('resultados-laboratorio/:id'));
    expect(paths.indexOf('resultados-laboratorio/sincronizaciones/importar')).toBeLessThan(
      paths.indexOf('resultados-laboratorio/sincronizaciones/:id'),
    );
  });

  it.each(RUTAS)('la ruta %s exige staff y lab_results:sync', (path) => {
    const ruta = rutasDelPanel().find((r) => r.path === path) as Route;
    expect(ruta.canActivate).toEqual([staffGuard, permissionsGuard]);
    expect(ruta.data?.['permissions']).toEqual(['lab_results:sync']);
  });

  it('las rutas de bloque A conservan sus permisos', () => {
    const permiso = (path: string) => rutasDelPanel().find((r) => r.path === path)?.data?.['permissions'];
    expect(permiso('resultados-laboratorio/revision')).toEqual(['lab_results:review']);
    expect(permiso('resultados-laboratorio/:id')).toEqual(['lab_results:read']);
  });

  describe('guards con la sesión simulada', () => {
    const estado = { url: '/admin/resultados-laboratorio/fuentes' } as RouterStateSnapshot;

    function configurar(rol: 'paciente' | 'recepcion' | 'doctor' | 'admin', permisos: string[]) {
      TestBed.configureTestingModule({
        providers: [
          { provide: AuthService, useValue: { isAdmin: () => rol === 'admin', isRecepcion: () => rol === 'recepcion', isDoctor: () => rol === 'doctor' } },
          { provide: PermissionsService, useValue: { hasAnyPermission: (p: string[]) => p.some((x) => permisos.includes(x)) } },
          { provide: Router, useValue: { createUrlTree: (comandos: string[]) => ({ comandos }) as unknown as UrlTree } },
        ],
      });
    }

    function evaluar(): unknown[] {
      const ruta = { data: { permissions: ['lab_results:sync'] } } as unknown as ActivatedRouteSnapshot;
      return [staffGuard, permissionsGuard].map((guard) => TestBed.runInInjectionContext(() => guard(ruta, estado)));
    }

    beforeEach(() => TestBed.resetTestingModule());

    it('ADMIN con lab_results:sync entra', () => {
      configurar('admin', ['lab_results:read', 'lab_results:review', 'lab_results:sync']);
      expect(evaluar()).toEqual([true, true]);
    });

    it.each([
      ['doctor', ['lab_results:create', 'lab_results:read', 'lab_results:review']],
      ['recepcion', ['lab_results:create', 'lab_results:read']],
    ] as const)('%s sin lab_results:sync es redirigido', (rol, permisos) => {
      configurar(rol, [...permisos]);
      const [personal, permiso] = evaluar();
      expect(personal).toBe(true);
      expect(permiso).not.toBe(true);
    });

    it('un PACIENTE no entra aunque tuviera el permiso', () => {
      configurar('paciente', ['lab_results:sync']);
      expect(evaluar()[0]).not.toBe(true);
    });
  });
});
