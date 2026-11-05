import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatIconModule } from '@angular/material/icon';
import { Header } from '../../shared/components/header/header';
import { Footer } from '../../shared/components/footer/footer';
import { AuthService } from '../../core/services/auth.service';
import { PermissionsService } from '../../core/services/permissions.service';
import { AsistenciaTratamientoService } from '../../core/services/asistencia-tratamiento.service';
import {
  EvaluacionResumenDTO,
} from '../../core/models/asistencia-tratamiento.models';

/**
 * Componente principal para el Asistente Inteligente de Tratamiento (CU18).
 *
 * Soporta modo PACIENTE (evaluación bajo demanda e historial clínico propio)
 * y modo MEDICO (auditoría y consulta del historial de pacientes).
 */
@Component({
  selector: 'app-ai-assistant',
  standalone: true,
  imports: [CommonModule, FormsModule, MatIconModule, Header, Footer],
  templateUrl: './ai-assistant.html',
})
export class AiAssistant implements OnInit {
  readonly authService = inject(AuthService);
  readonly permissionsService = inject(PermissionsService);
  readonly asistenciaService = inject(AsistenciaTratamientoService);

  // Control de pestañas
  readonly tabActiva = signal<'evaluacion' | 'historial'>('evaluacion');

  // Perfil y capacidades del usuario activo
  readonly esPaciente = computed(() => this.authService.isPaciente());
  readonly esDoctor = computed(() => this.authService.isDoctor());
  readonly puedeEvaluar = computed(
    () => this.esPaciente() || this.permissionsService.hasPermission('assistance:evaluate')
  );

  // Búsqueda para médicos en el historial
  readonly idPacienteMedico = signal<number | null>(null);

  // Modales
  readonly modalUrgenciaAbierto = signal<boolean>(false);
  readonly modalDetalleAbierto = signal<boolean>(false);

  // Paginación local del historial
  readonly paginaHistorial = signal<number>(1);
  readonly limitePorPagina = 10;

  // Reactividad con signals del servicio
  readonly evaluacionActual = this.asistenciaService.evaluacionActual;
  readonly isLoading = this.asistenciaService.isLoading;
  readonly errorMessage = this.asistenciaService.errorMessage;
  readonly errorCode = this.asistenciaService.errorCode;
  readonly retryAfterSeconds = this.asistenciaService.retryAfterSeconds;

  readonly historialData = this.asistenciaService.historial;
  readonly isLoadingHistorial = this.asistenciaService.isLoadingHistorial;
  readonly historialError = this.asistenciaService.historialError;

  readonly evaluacionDetalle = this.asistenciaService.selectedDetalle;
  readonly isLoadingDetalle = this.asistenciaService.isLoadingDetalle;
  readonly detalleError = this.asistenciaService.detalleError;

  // Lista del historial
  readonly itemsHistorial = computed<EvaluacionResumenDTO[]>(() => {
    const data = this.historialData();
    return data?.items ?? [];
  });

  ngOnInit(): void {
    if (this.esPaciente()) {
      this.cargarHistorial(1);
    }
  }

  cambiarTab(tab: 'evaluacion' | 'historial'): void {
    this.tabActiva.set(tab);
    if (tab === 'historial' && this.esPaciente() && !this.historialData()) {
      this.cargarHistorial(1);
    }
  }

  solicitarEvaluacion(forzarRecalculo: boolean = false): void {
    if (!this.puedeEvaluar() || this.isLoading()) return;
    this.asistenciaService.evaluar(forzarRecalculo).subscribe({
      next: () => {
        if (this.esPaciente()) {
          this.asistenciaService.getHistorial(1, this.limitePorPagina).subscribe({
            error: () => {},
          });
        }
      },
      error: () => {},
    });
  }

  cargarHistorial(page: number = 1): void {
    this.paginaHistorial.set(page);
    const idPaciente = this.esDoctor() ? this.idPacienteMedico() ?? undefined : undefined;
    this.asistenciaService.getHistorial(page, this.limitePorPagina, idPaciente).subscribe({
      error: () => {},
    });
  }

  buscarHistorialMedico(): void {
    if (!this.idPacienteMedico()) return;
    this.cargarHistorial(1);
  }

  paginaAnterior(): void {
    const pagina = this.paginaHistorial();
    if (pagina > 1) {
      this.cargarHistorial(pagina - 1);
    }
  }

  paginaSiguiente(): void {
    const data = this.historialData();
    const pagina = this.paginaHistorial();
    if (data && pagina < data.total_paginas) {
      this.cargarHistorial(pagina + 1);
    }
  }

  verDetalle(idEvaluacion: number): void {
    this.modalDetalleAbierto.set(true);
    this.asistenciaService.getEvaluacionById(idEvaluacion).subscribe({
      error: () => {},
    });
  }

  cerrarModalDetalle(): void {
    this.modalDetalleAbierto.set(false);
    this.asistenciaService.limpiarDetalle();
  }

  abrirModalUrgencia(): void {
    this.modalUrgenciaAbierto.set(true);
  }

  cerrarModalUrgencia(): void {
    this.modalUrgenciaAbierto.set(false);
  }

  // Helpers de presentación
  getIconoSeveridad(severidad: string): string {
    switch (severidad?.toUpperCase()) {
      case 'GRAVE':
        return 'shield';
      case 'MODERADA':
        return 'warning';
      case 'LEVE':
      default:
        return 'info';
    }
  }

  getClaseSeveridadBadge(severidad: string): string {
    switch (severidad?.toUpperCase()) {
      case 'GRAVE':
        return 'bg-error text-white';
      case 'MODERADA':
        return 'bg-amber-600 text-white';
      case 'LEVE':
      default:
        return 'bg-slate-500 text-white';
    }
  }

  getClaseSeveridadCard(severidad: string): string {
    switch (severidad?.toUpperCase()) {
      case 'GRAVE':
        return 'bg-error-container text-on-error-container border-error/40 border-2';
      case 'MODERADA':
        return 'bg-amber-50 text-amber-950 border-amber-300 border';
      case 'LEVE':
      default:
        return 'bg-surface-container-lowest text-on-surface border-outline-variant/60 border';
    }
  }

  getIconoRiesgo(nivel: string): string {
    switch (nivel?.toUpperCase()) {
      case 'ALTO':
        return 'shield';
      case 'MEDIO':
        return 'warning';
      case 'BAJO':
        return 'info';
      case 'SIN_RIESGO':
      default:
        return 'check_circle';
    }
  }

  getClaseRiesgo(nivel: string): string {
    switch (nivel?.toUpperCase()) {
      case 'ALTO':
        return 'bg-error-container text-on-error-container border border-error/40';
      case 'MEDIO':
        return 'bg-amber-100 text-amber-900 border border-amber-300';
      case 'BAJO':
        return 'bg-blue-100 text-blue-900 border border-blue-300';
      case 'SIN_RIESGO':
      default:
        return 'bg-emerald-100 text-emerald-900 border border-emerald-300';
    }
  }

  getIconoCategoria(categoria: string): string {
    switch (categoria?.toUpperCase()) {
      case 'HORARIO_ADMINISTRACION':
        return 'schedule';
      case 'ESTILO_VIDA':
        return 'favorite';
      case 'SIGNOS_ALARMA':
        return 'notification_important';
      case 'NUTRICION_HIDRATACION':
        return 'water_drop';
      case 'PRECAUCION_GENERAL':
      default:
        return 'health_and_safety';
    }
  }
}
