import { Manifiesto } from '../models/laboratory-sync.models';

/**
 * El informe de una sincronización (`GET /{id}`) trae solo `id_externo`, estado y error de cada ítem, no los datos
 * del manifiesto (CI, estudio, laboratorio, fecha). Para poder reintentar un ítem en `ERROR` la web conserva el
 * manifiesto original en `sessionStorage` (solo en esa pestaña y hasta cerrarla); si no está, el usuario lo vuelve a
 * cargar. Todo acceso al almacenamiento va en try/catch: puede estar bloqueado o lleno.
 */
const PREFIJO = 'cu11_manifiesto_';

export function guardarManifiesto(idSincronizacion: number, manifiesto: Manifiesto): void {
  try {
    sessionStorage.setItem(PREFIJO + idSincronizacion, JSON.stringify(manifiesto));
  } catch {
    /* sin almacenamiento: el usuario cargará el manifiesto al reintentar */
  }
}

export function leerManifiesto(idSincronizacion: number): Manifiesto | null {
  try {
    const texto = sessionStorage.getItem(PREFIJO + idSincronizacion);
    if (!texto) return null;
    const crudo: unknown = JSON.parse(texto);
    if (typeof crudo === 'object' && crudo !== null && Array.isArray((crudo as { items?: unknown }).items)) {
      return crudo as Manifiesto;
    }
    return null;
  } catch {
    return null;
  }
}
