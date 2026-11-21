/**
 * Validación de archivos en el cliente (ayuda de UX). El servidor es la autoridad: valida además la firma
 * (magic bytes) y el tipo de contenido, y su respuesta se muestra siempre.
 */

export const TAMANO_MAXIMO_BYTES = 10 * 1024 * 1024;
export const EXTENSIONES_PERMITIDAS: readonly string[] = ['.pdf', '.jpg', '.jpeg', '.png'];
export const ACCEPT_ARCHIVO = '.pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png';

/** Devuelve el mensaje del primer problema encontrado, o `null` si el archivo es aceptable. */
export function validarArchivoCliente(archivo: File | null | undefined): string | null {
  if (!archivo) return 'Seleccione el archivo del resultado.';
  const nombre = (archivo.name ?? '').toLowerCase();
  const punto = nombre.lastIndexOf('.');
  const extension = punto > 0 ? nombre.slice(punto) : '';
  if (!EXTENSIONES_PERMITIDAS.includes(extension)) {
    return 'El archivo debe ser PDF, JPG o PNG.';
  }
  if (archivo.size <= 0) return 'El archivo está vacío.';
  if (archivo.size > TAMANO_MAXIMO_BYTES) return 'El archivo supera el tamaño máximo de 10 MB.';
  return null;
}

/** Fecha local de hoy en formato `YYYY-MM-DD`. */
export function hoyIso(ahora: Date = new Date()): string {
  const mes = String(ahora.getMonth() + 1).padStart(2, '0');
  const dia = String(ahora.getDate()).padStart(2, '0');
  return `${ahora.getFullYear()}-${mes}-${dia}`;
}

export function esFechaFutura(fechaIso: string, ahora: Date = new Date()): boolean {
  return !!fechaIso && fechaIso > hoyIso(ahora);
}

export function formatearTamano(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

/** Extrae el nombre de archivo de una cabecera `Content-Disposition` (prefiere `filename*`). */
export function nombreDesdeContentDisposition(cabecera: string | null | undefined, respaldo: string): string {
  if (!cabecera) return respaldo;
  const extendido = /filename\*\s*=\s*UTF-8''([^;]+)/i.exec(cabecera);
  if (extendido) {
    try {
      return decodeURIComponent(extendido[1].trim());
    } catch {
      /* se intenta el nombre simple */
    }
  }
  const simple = /filename\s*=\s*"([^"]*)"/i.exec(cabecera) ?? /filename\s*=\s*([^;]+)/i.exec(cabecera);
  return simple ? simple[1].trim() : respaldo;
}
