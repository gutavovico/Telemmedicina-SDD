import { Component, signal } from '@angular/core';
import { provideRouter, Router } from '@angular/router';
import { AdminLayout } from '../../admin/admin-layout/admin-layout';
import { AuthService } from '../../../core/services/auth.service';
import { TestBed } from '@angular/core/testing';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';
import { describe, it, expect } from 'vitest';
import { EntityConfiguration } from './entity-configuration';
import { TenantService } from '../../../core/services/tenant.service';
import { tenantInterceptor } from '../../../core/interceptors/tenant.interceptor';

const base = 'http://localhost:8000/api/v1/tenant';
const identidad = { principal: '#001122', secundario: '#334455', logo: null };
const data = { identidad, direccion: null, sedes: [], servicios: [], horarios: [] };

@Component({ template: '' })
class RutaVacia {}

describe('CU33 configuración institucional', () => {
  it('recupera la marca al recargar con una sesión y los interceptores activos', async () => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(withInterceptors([tenantInterceptor])), provideHttpClientTesting()],
    });
    localStorage.setItem('access_token', 'sesion-ficticia');
    try {
      const tenant = TestBed.inject(TenantService);
      await Promise.resolve();
      const http = TestBed.inject(HttpTestingController);
      http.expectOne(base + '/context').flush({ clinica_id: 1, marca: identidad });
      expect(tenant.currentTenant()?.marca).toEqual(identidad);
      http.verify();
    } finally {
      localStorage.removeItem('access_token');
      localStorage.removeItem('current_tenant_context');
    }
  });

  it('aplica el tema de la cuenta al layout y lo retira al cambiar de usuario o salir', () => {
    const usuario = signal({ id_usuario: 7, id_clinica: 1 });
    const auth = {
      currentUser: usuario, isAuthenticated: () => false, isAdmin: () => true,
      isRecepcion: () => false, isDoctor: () => false, userDisplayName: () => '',
      userInitials: () => '', userPhoto: () => null, userRoleLabel: () => '',
    };
    TestBed.configureTestingModule({
      imports: [AdminLayout],
      providers: [provideRouter([]), provideHttpClient(), provideHttpClientTesting(),
                  {provide: AuthService, useValue: auth}],
    });
    const tenant = TestBed.inject(TenantService);
    const fixture = TestBed.createComponent(AdminLayout);
    tenant.loadTenantContext().subscribe();
    TestBed.inject(HttpTestingController).expectOne(base + '/context').flush({
      clinica_id: 1, usuario_id: 7, clinica_nombre: 'Central', tema: identidad,
    });
    fixture.detectChanges();
    const style = fixture.nativeElement.querySelector('.admin-panel').style;
    expect(style.getPropertyValue('--tema-principal')).toBe(identidad.principal);
    expect(style.getPropertyValue('--tema-secundario')).toBe(identidad.secundario);
    expect(style.getPropertyValue('--tema-en-principal')).toBe('#ffffff');
    tenant.currentTenant.update((context) => context && {
      ...context, tema: { principal: '#ffff00', secundario: '#ffff00' },
    });
    fixture.detectChanges();
    expect(style.getPropertyValue('--tema-en-principal')).toBe('#000000');
    expect(style.getPropertyValue('--tema-en-secundario')).toBe('#000000');
    tenant.currentTenant.update((context) => context && { ...context, es_super_admin: true });
    fixture.detectChanges();
    expect(style.getPropertyValue('--tema-principal')).toBe('');
    tenant.currentTenant.update((context) => context && { ...context, es_super_admin: false });
    usuario.set({ id_usuario: 8, id_clinica: 1 });
    fixture.detectChanges();
    expect(style.getPropertyValue('--tema-principal')).toBe('');
    tenant.clearTenant();
    fixture.detectChanges();
    expect(style.getPropertyValue('--tema-secundario')).toBe('');
  });

  it('ubica configuración al final y la activa únicamente en su ruta para el administrador', async () => {
    const esAdmin = signal(true);
    const auth = {
      currentUser: () => null, isAuthenticated: () => false, isAdmin: esAdmin,
      isRecepcion: () => false, isDoctor: () => false, userDisplayName: () => '',
      userInitials: () => '', userPhoto: () => null, userRoleLabel: () => '',
    };
    TestBed.configureTestingModule({
      imports: [AdminLayout],
      providers: [
        provideRouter(['admin/dashboard', 'admin/configuracion-entidad'].map(path => ({ path, component: RutaVacia }))),
        provideHttpClient(), provideHttpClientTesting(), { provide: AuthService, useValue: auth },
      ],
    });
    const router = TestBed.inject(Router);
    const fixture = TestBed.createComponent(AdminLayout);
    await router.navigateByUrl('/admin/dashboard');
    fixture.detectChanges();
    await fixture.whenStable();
    const links: NodeListOf<HTMLAnchorElement> = fixture.nativeElement.querySelectorAll('aside nav a');
    const configuracion = links[links.length - 1];
    expect(links[0].textContent).toContain('Dashboard');
    expect(configuracion.lastElementChild?.textContent).toBe('Configuración');
    expect(configuracion.firstElementChild?.textContent).toBe('settings');
    expect(configuracion.getAttribute('aria-current')).toBeNull();

    await router.navigateByUrl('/admin/configuracion-entidad?origen=menu');
    await fixture.whenStable();
    expect(configuracion.getAttribute('aria-current')).toBe('page');
    esAdmin.set(false);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('aside a[href="/admin/configuracion-entidad"]')).toBeNull();
  });

  it('conserva el formulario si falla y actualiza la marca desde el contexto tras guardar', () => {
    TestBed.configureTestingModule({
      imports: [EntityConfiguration],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    const fixture = TestBed.createComponent(EntityConfiguration);
    const component = fixture.componentInstance;
    const http = TestBed.inject(HttpTestingController);
    const tenant = TestBed.inject(TenantService);
    http.expectOne(base + '/configuracion').flush(data);
    fixture.detectChanges();
    expect(fixture.nativeElement.textContent).toContain('Apariencia de mi panel');
    component.colores.controls.principal.setValue('#123456');
    component.guardar('identidad', component.colores.getRawValue());
    http
      .expectOne(base + '/configuracion/identidad')
      .flush({ detail: 'Conflicto' }, { status: 409, statusText: 'Conflict' });
    expect(component.resultado()?.texto).toContain('Conflicto');
    expect(component.colores.value.principal).toBe('#123456');
    expect(component.resultado()?.tipo).toBe('error');
    component.guardar('identidad', component.colores.getRawValue());
    http.expectOne(base + '/configuracion/identidad').flush({ mensaje: 'Cambios guardados' });
    const marca = { ...identidad, principal: '#123456' };
    http.expectOne(base + '/context').flush({ clinica_id: 1, tema: marca });
    http.expectOne(base + '/configuracion').flush({ ...data, identidad: marca });
    expect(tenant.currentTenant()?.tema).toEqual(marca);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('section .success')?.textContent).toContain('Apariencia de mi panel');
    component.guardar('direccion', { valor: 'direccion-duplicada' });
    http.expectOne(base + '/configuracion/direccion')
      .flush({ detail: 'Dirección duplicada' }, { status: 409, statusText: 'Conflict' });
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('section .success')).toBeNull();
    expect(fixture.nativeElement.querySelectorAll('section')[2].querySelector('[role="alert"]')?.textContent)
      .toContain('Dirección duplicada');
    tenant.setSuperAdminTenant(2).subscribe();
    expect(tenant.currentTenant()?.tema).toBeNull();
    tenant.clearTenant();
    http.expectOne(base + '/context').flush({ clinica_id: 2, marca });
    expect(tenant.currentTenant()).toBeNull();
    http.verify();
  });
});
