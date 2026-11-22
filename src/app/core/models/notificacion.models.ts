export type CategoriaNotificacion = 'TODAS' | 'CITAS' | 'DOCUMENTOS' | 'SISTEMA';

export type CanalNotificacion = 'MULTI' | 'PUSH' | 'EMAIL' | 'SMS';

export interface NotificacionDTO {
  id_notificacion: number;
  id_clinica?: number | null;
  id_usuario: number;
  outbox_id?: number | null;
  rol_destinatario?: string | null;
  tipo?: string | null;
  categoria: string;
  canal?: string | null;
  canal_badge?: string | null;
  titulo?: string | null;
  mensaje?: string | null;
  recurso_tipo?: string | null;
  recurso_id?: string | null;
  enlace_accion?: string | null;
  payload_extra?: Record<string, unknown> | null;
  fecha_programada?: string | null;
  fecha_envio?: string | null;
  fecha_lectura?: string | null;
  estado: string;
  created_at: string;
}

export interface NotificacionResumenDTO {
  no_leidas: number;
  total: number;
  por_categoria: Record<string, number>;
}

export interface PreferenciasNotificacionDTO {
  notificaciones_push: boolean;
  notificaciones_email: boolean;
  notificaciones_sms: boolean;
}

export interface WebPushConfigDTO {
  public_key: string;
  habilitado: boolean;
}

export interface WebPushSubscriptionDTO {
  endpoint: string;
  keys: {
    p256dh: string;
    auth: string;
  };
  dispositivo_id?: string;
}

export interface DispositivoDTO {
  id_dispositivo: number;
  dispositivo_id: string;
  canal: string;
  estado: string;
  revision: number;
  creado_en: string;
}
