/**
 * Modelos de fuentes y sincronización de laboratorio (CU11, bloque B).
 * Derivados de `openspec/contracts/resultados-laboratorio.md` (secciones 1.1, 2.6, 2.7, 2.8 y 4). Los nombres de
 * campos, códigos y rutas son exactamente los del contrato.
 *
 * Nunca se envían `id_clinica` ni `tenant_id`: la clínica sale de la sesión (y el servidor los rechaza con 422).
 */

// ---------------------------------------------------------------------------
// Fuentes (2.6)
// ---------------------------------------------------------------------------
export type ActivaFuente = 'SI' | 'NO';

export interface FuenteLaboratorio {
  id_fuente: number;
  codigo: string;
  nombre: string;
  activa: ActivaFuente;
  created_at: string | null;
  updated_at: string | null;
}

export interface FuenteLaboratorioListResponse {
  items: FuenteLaboratorio[];
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
}

export interface FuenteLaboratorioQueryParams {
  activa?: ActivaFuente | '';
  page?: number;
  page_size?: number;
}

/** `FuenteLaboratorioCreateRequest`: el servidor normaliza el código a mayúsculas. */
export interface FuenteLaboratorioCreateRequest {
  codigo: string;
  nombre: string;
}

/** `FuenteLaboratorioUpdateRequest`: el código no se modifica. */
export interface FuenteLaboratorioUpdateRequest {
  nombre?: string;
  activa?: ActivaFuente;
}

// ---------------------------------------------------------------------------
// Manifiesto de lote (2.7)
// ---------------------------------------------------------------------------
export interface ItemManifiesto {
  id_externo: string;
  ci: string;
  complemento?: string | null;
  codigo_examen: string;
  laboratorio_origen: string;
  fecha_realizacion: string;
  nombre_archivo: string;
  id_orden?: number | null;
  observaciones?: string | null;
}

export interface Manifiesto {
  fuente: string;
  items: ItemManifiesto[];
}

// ---------------------------------------------------------------------------
// Sincronización (2.8)
// ---------------------------------------------------------------------------
export type EstadoSincronizacion = 'EN_PROCESO' | 'COMPLETADA' | 'COMPLETADA_CON_ERRORES' | 'FALLIDA';
export type ResultadoItem = 'INCORPORADO' | 'PENDIENTE_REVISION' | 'DUPLICADO' | 'ERROR';

export interface ItemSincronizacion {
  id_externo: string;
  resultado: ResultadoItem;
  id_resultado: number | null;
  codigo_error: string | null;
  /** En `PENDIENTE_REVISION` trae el motivo; en `ERROR`, el texto del servidor. */
  detalle: string | null;
  intento: number;
}

/** Cabecera (listado: sin `items`). */
export interface SincronizacionResumen {
  id_sincronizacion: number;
  id_fuente: number;
  fuente_codigo: string | null;
  tipo: string;
  estado: EstadoSincronizacion;
  total_items: number;
  incorporados: number;
  pendientes: number;
  duplicados: number;
  con_error: number;
  reintentos: number;
  id_usuario: number | null;
  proceso: string | null;
  iniciado_en: string | null;
  finalizado_en: string | null;
}

export interface Sincronizacion extends SincronizacionResumen {
  items: ItemSincronizacion[];
}

export interface SincronizacionListResponse {
  items: SincronizacionResumen[];
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
}

export interface SincronizacionQueryParams {
  page?: number;
  page_size?: number;
  id_fuente?: number | null;
  estado?: EstadoSincronizacion | '';
  fecha_desde?: string;
  fecha_hasta?: string;
}

/** Progreso de una subida multipart (`HttpEventType.UploadProgress`). */
export interface ProgresoSubida {
  tipo: 'progreso';
  /** 0 a 100; `null` cuando el navegador no informa el total. */
  porcentaje: number | null;
  cargados: number;
  total: number | null;
}

export interface RespuestaSubida {
  tipo: 'respuesta';
  sincronizacion: Sincronizacion;
}

export type EventoSubida = ProgresoSubida | RespuestaSubida;

// ---------------------------------------------------------------------------
// Límites del contrato (ayuda de UX; el servidor es la autoridad)
// ---------------------------------------------------------------------------
export const MAX_ITEMS_POR_LOTE = 50;
export const MAX_BYTES_POR_ARCHIVO = 10 * 1024 * 1024;
export const MAX_BYTES_POR_PETICION = 100 * 1024 * 1024;
/** Por encima de este total se sugiere partir el envío en lotes más pequeños. */
export const AVISO_BYTES_POR_PETICION = 50 * 1024 * 1024;
/** Starlette rechaza con 400 un campo de texto de más de 1 MB (el manifiesto). */
export const MAX_BYTES_MANIFIESTO = 1024 * 1024;
