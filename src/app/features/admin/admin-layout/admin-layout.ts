import { Component, computed, effect, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';
import { TenantService } from '../../../core/services/tenant.service';
import { normalizeAppRole } from '../../../core/models/auth.models';
import { TenantSelectorComponent } from '../../../shared/components/tenant-selector/tenant-selector';
import { InactivityWarning } from '../../auth/inactivity-warning/inactivity-warning';
import { paletaPanel } from './paleta-panel';

@Component({
  selector: 'app-admin-layout',
  imports: [CommonModule, RouterOutlet, RouterLink, RouterLinkActive, TenantSelectorComponent, InactivityWarning],
  templateUrl: './admin-layout.html',
  styleUrl: './admin-layout.css'
})
export class AdminLayout {
  readonly authService = inject(AuthService);
  readonly tenantService = inject(TenantService);
  private readonly router = inject(Router);

  readonly logoUrl = signal<string | null>(null);
  readonly temaPanel = computed(() => {
    const contexto = this.tenantService.currentTenant();
    const usuario = this.authService.currentUser();
    if (!contexto?.tema || !usuario || !this.authService.isAdmin() || contexto.es_super_admin
      || contexto.usuario_id !== usuario.id_usuario || contexto.clinica_id !== usuario.id_clinica) {
      return null;
    }
    return paletaPanel(contexto.tema);
  });
  constructor() {
    effect(onCleanup => {
      const context = this.tenantService.currentTenant();
      this.logoUrl.set(null);
      if (!context?.marca?.logo) return;
      let url: string | undefined;
      const subscription = this.tenantService.obtenerLogo().subscribe({
        next: blob => { url = URL.createObjectURL(blob); this.logoUrl.set(url); },
        error: () => this.logoUrl.set(null),
      });
      onCleanup(() => { subscription.unsubscribe(); if (url) URL.revokeObjectURL(url); });
    });
  }

  readonly isSidebarOpen = signal(false);
  readonly isDropdownOpen = signal(false);

  /** CU11: mismo criterio que `PermissionsService.hasPermission('lab_results:read')`, sin inyectar nada nuevo. */
  puedeVerResultadosLaboratorio(): boolean {
    return this.tenantService.isSuperAdmin() || this.tenantService.permisos().includes('lab_results:read');
  }

  canSeeReports(): boolean {
    const user = this.authService.currentUser();
    return this.authService.isAuthenticated()
      && this.authService.profileVerified()
      && normalizeAppRole(user?.rol) === 'admin'
      && user?.estado.toUpperCase() === 'ACTIVO'
      && typeof user.id_clinica === 'number'
      && user.id_clinica > 0;
  }

  toggleSidebar(): void {
    this.isSidebarOpen.update(v => !v);
  }

  closeSidebar(): void {
    this.isSidebarOpen.set(false);
  }

  openDropdown(): void {
    this.isDropdownOpen.set(true);
  }

  closeDropdown(): void {
    this.isDropdownOpen.set(false);
  }

  toggleDropdown(): void {
    this.isDropdownOpen.update(v => !v);
  }

  goToProfile(): void {
    this.closeDropdown();
    // El Super Admin no tiene perfil profesional: su panel canónico es CU30.
    if (this.tenantService.isSuperAdmin()) {
      this.router.navigate(['/admin/tenants']);
      return;
    }
    if (this.authService.isRecepcion()) {
      this.router.navigate(['/admin/agenda']);
      return;
    }
    if (this.authService.isDoctor()) {
      this.router.navigate(['/mi-perfil-medico']);
      return;
    }
    this.router.navigate(['/admin/dashboard']);
  }

  logout(): void {
    this.closeDropdown();
    this.authService.logout();
  }
}
