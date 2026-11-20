import { TestBed } from '@angular/core/testing';
import { ActivatedRouteSnapshot, Route, Router, RouterStateSnapshot, UrlTree } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';
import { permissionsGuard } from './core/guards/permissions.guard';
import { staffGuard } from './core/guards/panel-access.guard';
import { AuthService } from './core/services/auth.service';
import { PermissionsService } from './core/services/permissions.service';
import { routes } from './app.routes';

/** CU11 (tarea 4.5): las rutas web de resultados de laboratorio exigen staff y el permiso granular de cada pantalla. */
describe('Rutas de resultados de laboratorio (CU11)', () => {
  const ESPERADO: Record<string, string> = {
    'resultados-laboratorio': 'lab_results:read',
    'resultados-laboratorio/nuevo': 'lab_results:create',
    'resultados-laboratorio/revision': 'lab_results:review',
    'resultados-laboratorio/:id': 'lab_results:read',
  };

  function rutasDelPanel(): Route[] {
    const panel = routes.find((r) => r.path === 'admin');
    return panel?.children ?? [];
  }

  it('declara las cuatro rutas bajo /admin con el orden correcto (estáticas antes de :id)', () => {
    const rutas = rutasDelPanel().map((r) => r.path);
    for (const path of Object.keys(ESPERADO)) expect(rutas).toContain(path);
    expect(rutas.indexOf('resultados-laboratorio/nuevo')).toBeLessThan(rutas.indexOf('resultados-laboratorio/:id'));
    expect(rutas.indexOf('resultados-laboratorio/revision')).toBeLessThan(rutas.indexOf('resultados-laboratorio/:id'));
  });

  it.each(Object.entries(ESPERADO))('la ruta %s exige staff y el permiso %s', (path, permiso) => {
    const ruta = rutasDelPanel().find((r) => r.path === path) as Route;
    expect(ruta.canActivate).toEqual([staffGuard, permissionsGuard]);
    expect(ruta.data?.['permissions']).toEqual([permiso]);
  });

  describe('guards con la sesión simulada', () => {
    const estado = { url: '/admin/resultados-laboratorio' } as RouterStateSnapshot;

    function configurar(opciones: { rol: 'paciente' | 'recepcion' | 'doctor' | 'admin'; permisos: string[] }) {
      TestBed.configureTestingModule({
        providers: [
          {
            provide: AuthService,
            useValue: {
              isAdmin: () => opciones.rol === 'admin',
              isRecepcion: () => opciones.rol === 'recepcion',
              isDoctor: () => opciones.rol === 'doctor',
            },
          },
          { provide: PermissionsService, useValue: { hasAnyPermission: (p: string[]) => p.some((x) => opciones.permisos.includes(x)) } },
          { provide: Router, useValue: { createUrlTree: (comandos: string[]) => ({ comandos }) as unknown as UrlTree } },
        ],
      });
    }

    function evaluar(permiso: string): unknown[] {
      const ruta = { data: { permissions: [permiso] } } as unknown as ActivatedRouteSnapshot;
      return [staffGuard, permissionsGuard].map((guard) =>
        TestBed.runInInjectionContext(() => guard(ruta, estado)),
      );
    }

    beforeEach(() => TestBed.resetTestingModule());

    it('un PACIENTE no entra a las pantallas web aunque tuviera el permiso de lectura', () => {
      configurar({ rol: 'paciente', permisos: ['lab_results:read'] });
      const [personal] = evaluar('lab_results:read');
      expect(personal).not.toBe(true);
    });

    it('RECEPCION con create/read entra a listado y carga, pero no a la revisión', () => {
      configurar({ rol: 'recepcion', permisos: ['lab_results:create', 'lab_results:read'] });
      expect(evaluar('lab_results:read')).toEqual([true, true]);
      expect(evaluar('lab_results:create')).toEqual([true, true]);
      const [personal, permisos] = evaluar('lab_results:review');
      expect(personal).toBe(true);
      expect(permisos).not.toBe(true); // redirige a /sin-permisos
    });

    it('MEDICO con lab_results:review entra a la revisión', () => {
      configurar({ rol: 'doctor', permisos: ['lab_results:read', 'lab_results:review'] });
      expect(evaluar('lab_results:review')).toEqual([true, true]);
    });
  });
});
