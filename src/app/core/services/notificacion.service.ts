import { Injectable, computed, effect, inject, signal } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, catchError, of, tap } from 'rxjs';
import { environment } from '../../../environments/environment';
import { AuthService } from './auth.service';
import { WebPushService } from './web-push.service';
import { normalizeAppRole } from '../models/auth.models';
import {
  CategoriaNotificacion,
  NotificacionDTO,
  NotificacionResumenDTO,
  PreferenciasNotificacionDTO,
} from '../models/notificacion.models';

@Injectable({ providedIn: 'root' })
export class NotificacionService {
  private readonly http = inject(HttpClient);
  private readonly authService = inject(AuthService);
  private readonly webPushService = inject(WebPushService, { optional: true });

  readonly notificaciones = signal<NotificacionDTO[]>([]);
  readonly conteoNoLeidas = signal<number>(0);
  readonly totalNotificaciones = signal<number>(0);
  readonly cargando = signal<boolean>(false);
  readonly preferencias = signal<PreferenciasNotificacionDTO>({
    notificaciones_push: true,
    notificaciones_email: true,
    notificaciones_sms: false,
  });

  readonly recientes = computed(() => this.notificaciones().slice(0, 5));

  private get baseUrl(): string {
    return `${environment.apiUrl}/api/v1/notificaciones`;
  }

  constructor() {
    effect((onCleanup) => {
      const authenticated = this.authService.isAuthenticated();
      if (authenticated) {
        this.refrescarResumen().subscribe();
        this.webPushService?.suscribirWebPush().subscribe();
        if (typeof window !== 'undefined') {
          const timer = window.setInterval(() => {
            if (this.authService.isAuthenticated()) {
              this.refrescarResumen().subscribe();
            }
          }, 10000);
          onCleanup(() => window.clearInterval(timer));
        }
      } else {
        this.notificaciones.set([]);
        this.conteoNoLeidas.set(0);
        this.totalNotificaciones.set(0);
      }
    });
  }

  refrescarResumen(): Observable<NotificacionResumenDTO | null> {
    if (!this.authService.isAuthenticated()) {
      return of(null);
    }
    return this.http.get<NotificacionResumenDTO>(`${this.baseUrl}/resumen-no-leidas`).pipe(
      tap((res) => {
        this.conteoNoLeidas.set(res.no_leidas ?? 0);
        this.totalNotificaciones.set(res.total ?? 0);
      }),
      catchError(() => of(null)),
    );
  }

  cargarBandeja(
    categoria: CategoriaNotificacion = 'TODAS',
    soloNoLeidas = false,
    limite = 50,
  ): Observable<NotificacionDTO[]> {
    if (!this.authService.isAuthenticated()) {
      return of([]);
    }
    this.cargando.set(true);
    let params = new HttpParams().set('limite', String(limite));
    if (categoria && categoria !== 'TODAS') {
      params = params.set('categoria', categoria);
    }
    if (soloNoLeidas) {
      params = params.set('solo_no_leidas', 'true');
    }

    return this.http.get<NotificacionDTO[]>(`${this.baseUrl}/bandeja`, { params }).pipe(
      tap((items) => {
        this.notificaciones.set(items);
        if (categoria === 'TODAS' && !soloNoLeidas) {
          this.conteoNoLeidas.set(items.filter((n) => !n.fecha_lectura).length);
          this.totalNotificaciones.set(items.length);
        }
        this.cargando.set(false);
      }),
      catchError(() => {
        this.cargando.set(false);
        return of([]);
      }),
    );
  }

  marcarLeida(idNotificacion: number): Observable<NotificacionDTO | null> {
    return this.http
      .patch<NotificacionDTO>(`${this.baseUrl}/bandeja/${idNotificacion}/leer`, {})
      .pipe(
        tap((updated) => {
          this.notificaciones.update((list) =>
            list.map((item) => (item.id_notificacion === idNotificacion ? updated : item)),
          );
          this.conteoNoLeidas.update((c) => Math.max(0, c - 1));
        }),
        catchError(() => of(null)),
      );
  }

  marcarTodasLeidas(): Observable<{ actualizadas: number }> {
    return this.http
      .post<{ actualizadas: number }>(`${this.baseUrl}/bandeja/marcar-todas-leidas`, {})
      .pipe(
        tap(() => {
          const ahora = new Date().toISOString();
          this.notificaciones.update((list) =>
            list.map((item) => ({
              ...item,
              fecha_lectura: item.fecha_lectura ?? ahora,
              estado: 'LEIDA',
            })),
          );
          this.conteoNoLeidas.set(0);
        }),
        catchError(() => of({ actualizadas: 0 })),
      );
  }

  cargarPreferencias(): Observable<PreferenciasNotificacionDTO | null> {
    return this.http.get<PreferenciasNotificacionDTO>(`${this.baseUrl}/preferencias`).pipe(
      tap((prefs) => this.preferencias.set(prefs)),
      catchError(() => of(null)),
    );
  }

  actualizarPreferencias(
    dto: Partial<PreferenciasNotificacionDTO>,
  ): Observable<PreferenciasNotificacionDTO | null> {
    return this.http.put<PreferenciasNotificacionDTO>(`${this.baseUrl}/preferencias`, dto).pipe(
      tap((prefs) => this.preferencias.set(prefs)),
      catchError(() => of(null)),
    );
  }

  /** Resuelve la ruta de destino respetando rol y permisos del usuario autenticado. */
  resolverRutaDestino(notif: NotificacionDTO): string {
    const rol = normalizeAppRole(this.authService.currentUser()?.rol);
    const enlace = (notif.enlace_accion || '').trim();

    // Si el backend ya calculó un enlace específico (ej. /admin/fichas/:id o /fichas/:id),
    // respetarlo siempre que coincida con el alcance de permisos del rol actual.
    if (enlace.startsWith('/') && enlace !== '/notificaciones' && enlace !== '/admin/notificaciones') {
      if ((rol === 'doctor' || rol === 'admin') && enlace.startsWith('/admin/')) {
        return enlace;
      }
      if (rol === 'paciente' && !enlace.startsWith('/admin/')) {
        return enlace;
      }
    }

    const tipo = (notif.tipo || '').toUpperCase();
    const recursoTipo = (notif.recurso_tipo || '').toUpperCase();
    const recursoId = notif.recurso_id;

    if (rol === 'doctor') {
      if (tipo === 'PACIENTE_EN_ESPERA' || recursoTipo === 'SALA_VIRTUAL' || recursoTipo === 'TELECONSULTA') {
        return recursoId ? `/admin/teleconsulta/${recursoId}` : '/admin/teleconsulta';
      }
      if (tipo === 'CITA_CANCELADA') {
        return '/admin/fichas';
      }
      if (tipo === 'NUEVA_CITA_AGENDADA' || recursoTipo === 'CITA') {
        return '/admin/consultas';
      }
      if (tipo === 'RESULTADO_LAB_LISTO' || recursoTipo === 'DOCUMENTO' || recursoTipo === 'LABORATORIO') {
        return recursoId ? `/admin/documentos/${recursoId}` : '/admin/documentos';
      }
      return '/admin/inicio-medico';
    }

    if (rol === 'admin') {
      if (tipo === 'BACKUP' || recursoTipo === 'BACKUP') {
        return '/admin/backups';
      }
      return '/admin/dashboard';
    }

    // PACIENTE (y cualquier otro rol con permisos de paciente)
    if (tipo === 'SALA_VIRTUAL_ABIERTA' || recursoTipo === 'SALA_VIRTUAL' || recursoTipo === 'TELECONSULTA') {
      return recursoId ? `/citas/${recursoId}/teleconsulta` : '/teleconsulta';
    }
    if (tipo === 'TURNO_LIBERADO' || tipo === 'RECORDATORIO_CITA' || tipo === 'PAGO_CONFIRMADO' || recursoTipo === 'CITA') {
      return '/mis-citas';
    }
    if (tipo === 'MEDICACION_TRATAMIENTO' || recursoTipo === 'TRATAMIENTO' || recursoTipo === 'RECETA') {
      return '/recetas';
    }
    if (tipo === 'DOCUMENTO_DISPONIBLE' || recursoTipo === 'DOCUMENTO' || recursoTipo === 'LABORATORIO') {
      return recursoId ? `/mis-documentos/${recursoId}` : '/mis-documentos';
    }
    return '/notificaciones';
  }
}
