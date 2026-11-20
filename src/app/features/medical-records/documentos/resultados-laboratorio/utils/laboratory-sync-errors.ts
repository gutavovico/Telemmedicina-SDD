import { HttpErrorResponse } from '@angular/common/http';
import { ErrorResultadoInterpretado } from '../models/laboratory-result.models';
import { EstadoSincronizacion, ItemSincronizacion, ResultadoItem } from '../models/laboratory-sync.models';
import { interpretarErrorResultado, mensajeDeCodigo } from './laboratory-result-errors';

/**
 * Errores del bloque B. Reutiliza `interpretarErrorResultado` (acepta las tres formas de `detail`: objeto
 * `{codigo, mensaje}`, lista de validación de FastAPI y texto plano) y agrega lo propio de la ingestión:
 * - el `400` de texto plano de Starlette para un manifiesto de más de 1 MB (no es `LOTE_INVALIDO`);
 * - el texto del servidor en `LOTE_INVALIDO` / `ITEM_NO_REINTENTABLE`, que dice qué falló.
 */
export function interpretarErrorSincronizacion(error: unknown): ErrorResultadoInterpretado {
  const base = interpretarErrorResultado(error);
  if (!(error instanceof HttpErrorResponse)) return base;

  const cuerpo = (error.error ?? null) as { detail?: unknown } | null;
  const detalle = cuerpo && typeof cuerpo === 'object' ? cuerpo.detail : undefined;

  if (error.status === 400 && typeof detalle === 'string' && /exceeded maximum size/i.test(detalle)) {
    return {
      ...base,
      mensaje: 'El manifiesto supera 1 MB y el servidor lo rechazó. Divida el lote en envíos más pequeños.',
    };
  }
  if (
    (base.codigo === 'LOTE_INVALIDO' || base.codigo === 'ITEM_NO_REINTENTABLE') &&
    typeof detalle === 'object' &&
    detalle !== null &&
    !Array.isArray(detalle)
  ) {
    const mensajeServidor = (detalle as { mensaje?: unknown }).mensaje;
    if (typeof mensajeServidor === 'string' && mensajeServidor.trim()) {
      return { ...base, mensaje: `${base.mensaje} Detalle: ${mensajeServidor.trim()}` };
    }
  }
  return base;
}

export const ETIQUETAS_ESTADO_SINCRONIZACION: Record<EstadoSincronizacion, string> = {
  EN_PROCESO: 'En proceso',
  COMPLETADA: 'Completada',
  COMPLETADA_CON_ERRORES: 'Completada con errores',
  FALLIDA: 'Fallida',
};

export const ETIQUETAS_RESULTADO_ITEM: Record<ResultadoItem, string> = {
  INCORPORADO: 'Incorporado',
  PENDIENTE_REVISION: 'Pendiente de revisión',
  DUPLICADO: 'Duplicado',
  ERROR: 'Error',
};

/**
 * Texto para la columna «Código y mensaje» del informe: en `ERROR` el código con su mensaje en español (o el
 * detalle del servidor si el código no es conocido); en `PENDIENTE_REVISION` el motivo.
 */
export function mensajeDeItem(
  item: ItemSincronizacion,
  motivosPendiente: Readonly<Record<string, string>> = {},
): { codigo: string | null; mensaje: string | null } {
  if (item.resultado === 'ERROR') {
    const codigo = item.codigo_error;
    const mensaje = codigo ? mensajeDeCodigo(codigo, item.detalle ?? undefined) : (item.detalle ?? null);
    return { codigo, mensaje };
  }
  if (item.resultado === 'PENDIENTE_REVISION') {
    const motivo = item.detalle;
    return { codigo: motivo, mensaje: motivo ? (motivosPendiente[motivo] ?? motivo) : null };
  }
  if (item.resultado === 'DUPLICADO') {
    return { codigo: null, mensaje: 'Ya estaba registrado: no se creó un resultado nuevo.' };
  }
  return { codigo: null, mensaje: null };
}
