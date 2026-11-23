import { Component, OnInit, computed, effect, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { Header } from '../../../shared/components/header/header';
import { Footer } from '../../../shared/components/footer/footer';
import { NotificacionService } from '../../../core/services/notificacion.service';
import { WebPushService } from '../../../core/services/web-push.service';
import { AuthService } from '../../../core/services/auth.service';
import { normalizeAppRole } from '../../../core/models/auth.models';
import {
  CategoriaNotificacion,
  NotificacionDTO,
} from '../../../core/models/notificacion.models';

export interface GrupoNotificaciones {
  etiqueta: string;
  items: NotificacionDTO[];
}

@Component({
  selector: 'app-notificaciones-center',
  imports: [CommonModule, Header, Footer],
  templateUrl: './notificaciones-center.component.html',
  styleUrl: './notificaciones-center.component.css',
})
export class NotificacionesCenterComponent implements OnInit {
  readonly notificacionService = inject(NotificacionService);
  readonly webPushService = inject(WebPushService);
  readonly authService = inject(AuthService);
  private readonly router = inject(Router);

  readonly tabActiva = signal<CategoriaNotificacion>('TODAS');
  readonly soloNoLeidas = signal<boolean>(false);
  readonly mostrarPreferencias = signal<boolean>(false);
  readonly mensajeEstado = signal<string | null>(null);

  readonly esVistaAdmin = computed(() => this.router.url.startsWith('/admin'));

  readonly esMedico = computed(
    () => normalizeAppRole(this.authService.currentUser()?.rol) === 'doctor',
  );

  readonly grupos = computed<GrupoNotificaciones[]>(() => {
    const lista = this.notificacionService.notificaciones();
    const hoy: NotificacionDTO[] = [];
    const ayer: NotificacionDTO[] = [];
    const anteriores: NotificacionDTO[] = [];

    const ahora = new Date();
    const inicioHoy = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate()).getTime();
    const inicioAyer = inicioHoy - 24 * 60 * 60 * 1000;

    for (const item of lista) {
      const ts = new Date(item.created_at).getTime();
      if (ts >= inicioHoy) {
        hoy.push(item);
      } else if (ts >= inicioAyer) {
        ayer.push(item);
      } else {
        anteriores.push(item);
      }
    }

    const res: GrupoNotificaciones[] = [];
    if (hoy.length > 0) res.push({ etiqueta: 'Hoy', items: hoy });
    if (ayer.length > 0) res.push({ etiqueta: 'Ayer', items: ayer });
    if (anteriores.length > 0) res.push({ etiqueta: 'Anteriores', items: anteriores });
    return res;
  });

  private ultimoTotalObservado = -1;

  constructor() {
    effect(() => {
      const total = this.notificacionService.totalNotificaciones();
      if (this.ultimoTotalObservado !== -1 && total !== this.ultimoTotalObservado) {
        this.recargar();
      }
      this.ultimoTotalObservado = total;
    });
  }

  ngOnInit(): void {
    this.recargar();
    this.notificacionService.cargarPreferencias().subscribe();
  }

  seleccionarTab(tab: CategoriaNotificacion): void {
    this.tabActiva.set(tab);
    this.recargar();
  }

  toggleSoloNoLeidas(): void {
    this.soloNoLeidas.update((v) => !v);
    this.recargar();
  }

  recargar(): void {
    this.notificacionService
      .cargarBandeja(this.tabActiva(), this.soloNoLeidas(), 60)
      .subscribe();
  }

  marcarTodasLeidas(): void {
    this.notificacionService.marcarTodasLeidas().subscribe((res) => {
      if (res.actualizadas > 0) {
        this.mostrarMensaje(`Se marcaron ${res.actualizadas} notificaciones como leídas.`);
      }
    });
  }

  abrirNotificacion(notif: NotificacionDTO): void {
    const destino = this.notificacionService.resolverRutaDestino(notif);
    if (!notif.fecha_lectura) {
      this.notificacionService.marcarLeida(notif.id_notificacion).subscribe(() => {
        this.router.navigateByUrl(destino);
      });
    } else {
      this.router.navigateByUrl(destino);
    }
  }

  activarPushNavegador(): void {
    this.webPushService.suscribirWebPush().subscribe((res) => {
      if (res) {
        this.mostrarMensaje('Notificaciones Push activadas en este navegador.');
      } else {
        this.mostrarMensaje('No fue posible activar Push (verifique los permisos del navegador).');
      }
    });
  }

  togglePreferencia(campo: 'notificaciones_push' | 'notificaciones_email' | 'notificaciones_sms'): void {
    const actual = this.notificacionService.preferencias();
    this.notificacionService
      .actualizarPreferencias({ [campo]: !actual[campo] })
      .subscribe(() => this.mostrarMensaje('Preferencias de notificación actualizadas.'));
  }

  obtenerIcono(notif: NotificacionDTO): string {
    const t = (notif.tipo || '').toUpperCase();
    const r = (notif.recurso_tipo || '').toUpperCase();
    if (t === 'SALA_VIRTUAL_ABIERTA' || t === 'PACIENTE_EN_ESPERA' || r === 'SALA_VIRTUAL') {
      return 'videocam';
    }
    if (t === 'TURNO_LIBERADO' || t === 'NUEVA_CITA_AGENDADA' || t === 'CITA_CANCELADA') {
      return 'event_available';
    }
    if (t === 'RECORDATORIO_CITA' || r === 'CITA') {
      return 'schedule';
    }
    if (t === 'MEDICACION_TRATAMIENTO' || r === 'TRATAMIENTO') {
      return 'medication';
    }
    if (t === 'DOCUMENTO_DISPONIBLE' || t === 'RESULTADO_LAB_LISTO' || r === 'DOCUMENTO') {
      return 'description';
    }
    return 'notifications';
  }

  obtenerColorIcono(notif: NotificacionDTO): string {
    const t = (notif.tipo || '').toUpperCase();
    if (t === 'SALA_VIRTUAL_ABIERTA' || t === 'PACIENTE_EN_ESPERA') {
      return 'bg-emerald-50 text-emerald-700';
    }
    if (t === 'TURNO_LIBERADO' || t === 'NUEVA_CITA_AGENDADA') {
      return 'bg-teal-50 text-teal-700';
    }
    if (t === 'MEDICACION_TRATAMIENTO') {
      return 'bg-amber-50 text-amber-700';
    }
    if (t === 'DOCUMENTO_DISPONIBLE' || t === 'RESULTADO_LAB_LISTO') {
      return 'bg-blue-50 text-blue-700';
    }
    return 'bg-slate-100 text-primary';
  }

  obtenerEtiquetaAccion(notif: NotificacionDTO): string {
    const t = (notif.tipo || '').toUpperCase();
    const r = (notif.recurso_tipo || '').toUpperCase();
    if (t === 'SALA_VIRTUAL_ABIERTA' || t === 'PACIENTE_EN_ESPERA' || r === 'SALA_VIRTUAL') {
      return 'Ir a sala virtual';
    }
    if (t === 'MEDICACION_TRATAMIENTO' || r === 'TRATAMIENTO' || r === 'RECETA') {
      return 'Ver tratamiento';
    }
    if (t === 'DOCUMENTO_DISPONIBLE' || t === 'RESULTADO_LAB_LISTO' || r === 'DOCUMENTO') {
      return 'Ver documento';
    }
    return 'Ver cita';
  }

  obtenerIconoCanal(badge?: string | null): string {
    const b = (badge || 'Push').toLowerCase();
    if (b === 'correo' || b === 'email') return 'mail';
    if (b === 'whatsapp' || b === 'sms') return 'chat_bubble_outline';
    return 'smartphone';
  }

  formatearTiempo(iso: string): string {
    const fecha = new Date(iso);
    const diffMin = Math.floor((Date.now() - fecha.getTime()) / 60000);
    if (diffMin < 1) return 'Ahora';
    if (diffMin < 60) return `Hace ${diffMin} min`;
    const diffHoras = Math.floor(diffMin / 60);
    if (diffHoras < 24) return `Hace ${diffHoras} h`;
    return fecha.toLocaleTimeString('es-BO', { hour: '2-digit', minute: '2-digit' });
  }

  private mostrarMensaje(msg: string): void {
    this.mensajeEstado.set(msg);
    setTimeout(() => this.mensajeEstado.set(null), 3500);
  }
}
