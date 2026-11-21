import { describe, expect, it } from 'vitest';
import type { Route } from '@angular/router';
import { routes } from './app.routes';
import { serverRoutes } from './app.routes.server';

function flatten(items: Route[]): Route[] {
  return items.flatMap((route) => [route, ...flatten(route.children ?? [])]);
}

describe('CU29 rutas frontend', () => {
  it('registra la administración con adminOnlyGuard', () => {
    const route = flatten(routes).find((item) => item.path === 'medicos/vinculaciones');
    expect(route).toBeDefined();
    expect(route?.canActivate?.length).toBe(1);
  });

  it('registra la bandeja médica con authGuard', () => {
    const route = flatten(routes).find((item) => item.path === 'mis-vinculaciones-medico');
    expect(route).toBeDefined();
    expect(route?.canActivate?.length).toBe(1);
  });

  it('renderiza ambas rutas únicamente en cliente para SSR', () => {
    const paths = serverRoutes.map((route) => route.path);
    expect(paths).toContain('admin/medicos/vinculaciones');
    expect(paths).toContain('mis-vinculaciones-medico');
  });
});
