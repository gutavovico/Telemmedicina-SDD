import { Injectable, inject, signal } from '@angular/core';
import { HttpClient, HttpContext } from '@angular/common/http';
import { Observable, from, of, switchMap, catchError, tap } from 'rxjs';
import { environment } from '../../../environments/environment';
import { SKIP_AUTH_LOGOUT } from '../interceptors/auth.interceptor';
import { obtenerDispositivoId } from '../utils/device-id.util';
import {
  DispositivoDTO,
  WebPushConfigDTO,
  WebPushSubscriptionDTO,
} from '../models/notificacion.models';

@Injectable({ providedIn: 'root' })
export class WebPushService {
  private readonly http = inject(HttpClient);
  readonly estadoPermiso = signal<NotificationPermission | 'unsupported'>(
    this.detectarPermisoInicial(),
  );
  readonly suscrito = signal(false);

  private get baseUrl(): string {
    return `${environment.apiUrl}/api/v1/notificaciones`;
  }

  private detectarPermisoInicial(): NotificationPermission | 'unsupported' {
    if (!this.estaSoportado()) {
      return 'unsupported';
    }
    return Notification.permission;
  }

  estaSoportado(): boolean {
    return (
      typeof window !== 'undefined' &&
      'serviceWorker' in navigator &&
      'PushManager' in window &&
      'Notification' in window
    );
  }

  suscribirWebPush(): Observable<DispositivoDTO | null> {
    if (!this.estaSoportado()) {
      return of(null);
    }

    const backgroundContext = new HttpContext().set(SKIP_AUTH_LOGOUT, true);

    return this.http
      .get<WebPushConfigDTO>(`${this.baseUrl}/web-push/config`, { context: backgroundContext })
      .pipe(
        switchMap((cfg) => {
          if (!cfg?.habilitado || !cfg.public_key) {
            return of(null);
          }
          return from(this.obtenerOSuscribirPush(cfg.public_key));
        }),
        switchMap((sub) => {
          if (!sub) {
            return of(null);
          }
          const json = sub.toJSON();
          const dto: WebPushSubscriptionDTO = {
            endpoint: sub.endpoint,
            keys: {
              p256dh: json.keys?.['p256dh'] || '',
              auth: json.keys?.['auth'] || '',
            },
            dispositivo_id: obtenerDispositivoId(),
          };
          return this.http
            .post<DispositivoDTO>(`${this.baseUrl}/web-push/subscripcion`, dto, {
              context: backgroundContext,
            })
            .pipe(tap(() => this.suscrito.set(true)));
        }),
        catchError(() => of(null)),
      );
  }

  revocarDispositivo(): Observable<void> {
    if (typeof window === 'undefined') {
      return of(undefined);
    }
    return this.http
      .delete<void>(`${this.baseUrl}/dispositivos/${obtenerDispositivoId()}`)
      .pipe(
        tap(() => this.suscrito.set(false)),
        catchError(() => of(undefined)),
      );
  }

  private async obtenerOSuscribirPush(publicKey: string): Promise<PushSubscription | null> {
    let permiso = Notification.permission;
    if (permiso === 'default') {
      permiso = await Notification.requestPermission();
    }
    this.estadoPermiso.set(permiso);
    if (permiso !== 'granted') {
      return null;
    }

    let reg = await navigator.serviceWorker.getRegistration('/custom-sw.js');
    if (!reg) {
      await navigator.serviceWorker.register('/custom-sw.js', { scope: '/' });
    }
    reg = await navigator.serviceWorker.ready;
    if (!reg.pushManager) {
      return null;
    }

    let sub = await reg.pushManager.getSubscription();
    if (!sub) {
      sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(publicKey) as BufferSource,
      });
    }
    return sub;
  }

  private urlBase64ToUint8Array(base64String: string): Uint8Array {
    const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    const rawData = window.atob(base64);
    return Uint8Array.from([...rawData].map((c) => c.charCodeAt(0)));
  }
}
