/**
 * Modelos de Resultados de Laboratorio (CU11, bloque A).
 * Derivados de `openspec/contracts/resultados-laboratorio.md` (secciones 1, 2 y 3). Los nombres de campos,
 * códigos de error y rutas son exactamente los del contrato.
 *
 * Nunca se envían `id_clinica`, `tenant_id`, `estado` ni `origen` en las peticiones: la clínica sale de la sesión.
 */

export type EstadoResultado = 'INCORPORADO' | 'PENDIENTE_REVISION' | 'ANULADO';
export type OrigenResultado = 'MANUAL' | 'SINCRONIZADO';

export type MotivoPendiente =
  | 'PACIENTE_NO_ENCONTRADO'
  | 'PACIENTE_AMBIGUO'
  | 'EXAMEN_NO_VALIDO'
  | 'ORDEN_NO_VALIDA'
  | 'ORDEN_PACIENTE_NO_COINCIDE';

/** Datos crudos recibidos de la fuente; solo visibles con `lab_results:review`. */
export interface DatosCorrespondencia {
  ci?: string | null;
  complemento?: string | null;
  codigo_examen?: string | null;
  id_orden?: number | null;
  [campo: string]: unknown;
}

/** Elemento de listado (sin `observaciones` ni `datos_correspondencia`). */
export interface ResultadoLaboratorioResumen {
  id_resultado: number;
  id_clinica: number;
  estado: EstadoResultado;
  origen: OrigenResultado;
  id_paciente: number | null;
  paciente_nombre: string | null;
  id_orden: number | null;
  id_examen: number | null;
  codigo_examen: string;
  nombre_examen: string | null;
  laboratorio_origen: string;
  fecha_realizacion: string;
  nombre_archivo: string;
  content_type: string;
  tamano_bytes: number;
  hash_archivo: string | null;
  id_documento: number | null;
  id_fuente: number | null;
  fuente_codigo: string | null;
  id_externo: string | null;
  id_sincronizacion: number | null;
  motivo_pendiente: MotivoPendiente | null;
  registrado_por: number | null;
  registrado_por_nombre: string | null;
  proceso: string | null;
  registrado_en: string | null;
  resuelto_por: number | null;
  resuelto_en: string | null;
  motivo_resolucion: string | null;
}

/** Detalle completo (`ResultadoLaboratorio` del contrato). */
export interface ResultadoLaboratorio extends ResultadoLaboratorioResumen {
  observaciones: string | null;
  datos_correspondencia: DatosCorrespondencia | null;
}

export interface ResultadoLaboratorioListResponse {
  items: ResultadoLaboratorioResumen[];
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
}

export interface ResultadoLaboratorioQueryParams {
  page?: number;
  page_size?: number;
  id_paciente?: number | null;
  codigo_examen?: string;
  laboratorio_origen?: string;
  origen?: OrigenResultado | '';
  id_fuente?: number | null;
  fecha_desde?: string;
  fecha_hasta?: string;
  estado?: EstadoResultado | '';
}

/** Datos de la carga manual (se envían como `multipart/form-data`). */
export interface CargaManualDatos {
  id_paciente: number;
  codigo_examen: string;
  fecha_realizacion: string;
  laboratorio_origen: string;
  id_orden?: number | null;
  observaciones?: string | null;
  archivo: File;
}

export interface ResolverAsignarRequest {
  accion: 'ASIGNAR';
  id_paciente: number;
  codigo_examen: string;
  id_orden?: number | null;
}

export interface ResolverDescartarRequest {
  accion: 'DESCARTAR';
  motivo: string;
}

export type ResolverPendienteRequest = ResolverAsignarRequest | ResolverDescartarRequest;

export interface AnularResultadoRequest {
  motivo: string;
}

/** Archivo descargado con el `Content-Type` real devuelto por el servidor. */
export interface ArchivoDescargado {
  blob: Blob;
  contentType: string;
  nombre: string;
}

/** Permisos del contrato (sección 1). La descarga exige `read` y `descarga` a la vez. */
export const PERMISOS_RESULTADOS = {
  create: 'lab_results:create',
  read: 'lab_results:read',
  review: 'lab_results:review',
  sync: 'lab_results:sync',
  descarga: 'documents:read:lab_results',
} as const;

/** Códigos de error de dominio del contrato (sección 1.1) que puede devolver el backend de bloque A. */
export type CodigoErrorResultado =
  | 'ARCHIVO_TIPO_NO_PERMITIDO'
  | 'ARCHIVO_FIRMA_INVALIDA'
  | 'ARCHIVO_TAMANO_EXCEDIDO'
  | 'ARCHIVO_VACIO'
  | 'ARCHIVO_NO_ENCONTRADO'
  | 'PACIENTE_NO_ENCONTRADO'
  | 'EXAMEN_NO_ENCONTRADO'
  | 'ORDEN_NO_ENCONTRADA'
  | 'ORDEN_PACIENTE_NO_COINCIDE'
  | 'ORDEN_NO_FIRMADA'
  | 'ORDEN_SIN_EXAMEN'
  | 'RESULTADO_DUPLICADO'
  | 'RESULTADO_NO_ENCONTRADO'
  | 'ESTADO_NO_PERMITIDO'
  | 'ALMACENAMIENTO_FALLIDO'
  // Bloque B (fuentes y sincronización), contrato 1.1
  | 'ARCHIVO_AUSENTE'
  | 'FUENTE_NO_ENCONTRADA'
  | 'FUENTE_INACTIVA'
  | 'FUENTE_DUPLICADA'
  | 'LOTE_INVALIDO'
  | 'CONTENIDO_DISTINTO'
  | 'ITEM_NO_REINTENTABLE'
  | 'SINCRONIZACION_NO_ENCONTRADA'
  | 'ERROR_INTERNO';

/** Error de dominio: `{"detail": {"codigo", "mensaje"}}`. */
export interface ErrorDominioDetalle {
  codigo: string;
  mensaje: string;
}

/** Elemento de la forma de lista de FastAPI para errores de validación. */
export interface ErrorValidacionDetalle {
  type?: string;
  loc?: Array<string | number>;
  msg?: string;
}

/** Error ya interpretado, listo para mostrar. */
export interface ErrorResultadoInterpretado {
  mensaje: string;
  codigo: string | null;
  /** Mensajes por campo del formulario (`archivo`, `id_paciente`, `codigo_examen`, ...). */
  campos: Record<string, string>;
  status: number;
}
