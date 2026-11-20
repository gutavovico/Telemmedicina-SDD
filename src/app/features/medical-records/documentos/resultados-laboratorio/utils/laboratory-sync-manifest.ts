import {
  AVISO_BYTES_POR_PETICION,
  ItemManifiesto,
  MAX_BYTES_MANIFIESTO,
  MAX_BYTES_POR_PETICION,
  MAX_ITEMS_POR_LOTE,
  Manifiesto,
} from '../models/laboratory-sync.models';
import { esFechaFutura, formatearTamano, validarArchivoCliente } from './laboratory-result-file';

/**
 * Validación previa del lote en el cliente (ayuda de UX, contrato 2.7 y 4.4). El servidor es la autoridad: su
 * respuesta se muestra siempre. Nada de esto se envía; solo evita viajes inútiles de hasta 100 MB.
 */

const CAMPOS_DE_CLINICA = ['id_clinica', 'tenant_id'] as const;
const MAX_MENSAJES = 15;
const FECHA_ISO = /^\d{4}-\d{2}-\d{2}$/;

export interface ResultadoValidacionLote {
  /** Manifiesto listo para enviar (con la `fuente` elegida) o `null` si hay errores bloqueantes del manifiesto. */
  manifiesto: Manifiesto | null;
  errores: string[];
  avisos: string[];
  items: number;
  totalBytes: number;
}

type Registro = Record<string, unknown>;

function esRegistro(valor: unknown): valor is Registro {
  return typeof valor === 'object' && valor !== null && !Array.isArray(valor);
}

function bytesDeTexto(texto: string): number {
  return new TextEncoder().encode(texto).length;
}

/** Valida un campo de texto obligatorio con longitud entre 1 y `max` (tras recortar espacios). */
function textoObligatorio(item: Registro, campo: string, max: number, errores: string[], etiqueta: string): void {
  const valor = item[campo];
  if (typeof valor !== 'string' || valor.trim().length === 0) {
    errores.push(`${etiqueta}: «${campo}» es obligatorio y debe ser texto.`);
  } else if (valor.trim().length > max) {
    errores.push(`${etiqueta}: «${campo}» admite hasta ${max} caracteres.`);
  }
}

function validarItem(item: unknown, posicion: number, ahora: Date): { errores: string[]; item: Registro | null } {
  const errores: string[] = [];
  if (!esRegistro(item)) {
    return { errores: [`Ítem ${posicion}: debe ser un objeto JSON.`], item: null };
  }
  const id = typeof item['id_externo'] === 'string' && item['id_externo'].trim() ? ` (${item['id_externo'].trim()})` : '';
  const etiqueta = `Ítem ${posicion}${id}`;

  for (const campo of CAMPOS_DE_CLINICA) {
    if (campo in item) errores.push(`${etiqueta}: el campo «${campo}» no se acepta; la clínica la determina la sesión.`);
  }
  textoObligatorio(item, 'id_externo', 100, errores, etiqueta);
  textoObligatorio(item, 'ci', 20, errores, etiqueta);
  textoObligatorio(item, 'codigo_examen', 50, errores, etiqueta);
  textoObligatorio(item, 'laboratorio_origen', 200, errores, etiqueta);
  textoObligatorio(item, 'nombre_archivo', 255, errores, etiqueta);

  const complemento = item['complemento'];
  if (complemento != null && (typeof complemento !== 'string' || complemento.trim().length > 10)) {
    errores.push(`${etiqueta}: «complemento» debe ser texto de hasta 10 caracteres.`);
  }
  const fecha = item['fecha_realizacion'];
  if (typeof fecha !== 'string' || !FECHA_ISO.test(fecha) || Number.isNaN(Date.parse(fecha))) {
    errores.push(`${etiqueta}: «fecha_realizacion» debe tener el formato AAAA-MM-DD.`);
  } else if (esFechaFutura(fecha, ahora)) {
    errores.push(`${etiqueta}: «fecha_realizacion» no puede ser posterior a hoy.`);
  }
  const orden = item['id_orden'];
  if (orden != null && (typeof orden !== 'number' || !Number.isInteger(orden) || orden < 1)) {
    errores.push(`${etiqueta}: «id_orden» debe ser un entero positivo o nulo.`);
  }
  const observaciones = item['observaciones'];
  if (observaciones != null && (typeof observaciones !== 'string' || observaciones.length > 2000)) {
    errores.push(`${etiqueta}: «observaciones» debe ser texto de hasta 2000 caracteres.`);
  }
  return { errores, item };
}

/** Valida el manifiesto (texto JSON) y los archivos seleccionados contra las reglas del contrato. */
export function validarLote(
  textoManifiesto: string,
  archivos: readonly File[],
  fuenteCodigo: string | null,
  ahora: Date = new Date(),
): ResultadoValidacionLote {
  const errores: string[] = [];
  const avisos: string[] = [];
  const totalBytes = archivos.reduce((suma, archivo) => suma + archivo.size, 0);
  let manifiesto: Manifiesto | null = null;
  let cantidad = 0;

  if (!fuenteCodigo) errores.push('Seleccione la fuente de laboratorio.');

  const texto = textoManifiesto.trim();
  let crudo: unknown = null;
  if (!texto) {
    errores.push('Cargue o pegue el manifiesto JSON del lote.');
  } else if (bytesDeTexto(texto) > MAX_BYTES_MANIFIESTO) {
    errores.push('El manifiesto supera 1 MB; el servidor lo rechaza. Divida el lote.');
  } else {
    try {
      crudo = JSON.parse(texto);
    } catch {
      errores.push('El manifiesto no es un JSON válido.');
    }
  }

  if (crudo !== null) {
    if (!esRegistro(crudo)) {
      errores.push('El manifiesto debe ser un objeto JSON con «items» (y, opcionalmente, «fuente»).');
    } else {
      for (const campo of CAMPOS_DE_CLINICA) {
        if (campo in crudo) errores.push(`El campo «${campo}» no se acepta; la clínica la determina la sesión.`);
      }
      const fuenteDelManifiesto = crudo['fuente'];
      if (fuenteDelManifiesto != null) {
        if (typeof fuenteDelManifiesto !== 'string') {
          errores.push('«fuente» debe ser el código de la fuente.');
        } else if (fuenteCodigo && fuenteDelManifiesto.trim().toUpperCase() !== fuenteCodigo.toUpperCase()) {
          errores.push(`La fuente del manifiesto («${fuenteDelManifiesto}») no coincide con la fuente seleccionada («${fuenteCodigo}»).`);
        }
      }
      const items = crudo['items'];
      if (!Array.isArray(items)) {
        errores.push('El manifiesto debe incluir «items» como una lista.');
      } else if (items.length === 0) {
        errores.push('El lote no tiene ítems.');
      } else {
        cantidad = items.length;
        if (items.length > MAX_ITEMS_POR_LOTE) {
          errores.push(`El lote admite como máximo ${MAX_ITEMS_POR_LOTE} ítems (tiene ${items.length}).`);
        }
        const vistos = new Set<string>();
        const repetidos = new Set<string>();
        const referenciados = new Set<string>();
        items.forEach((elemento, indice) => {
          const resultado = validarItem(elemento, indice + 1, ahora);
          errores.push(...resultado.errores);
          const item = resultado.item;
          if (!item) return;
          const id = typeof item['id_externo'] === 'string' ? item['id_externo'].trim() : '';
          if (id) {
            if (vistos.has(id)) repetidos.add(id);
            vistos.add(id);
          }
          if (typeof item['nombre_archivo'] === 'string' && item['nombre_archivo'].trim()) {
            referenciados.add(item['nombre_archivo'].trim());
          }
        });
        for (const id of repetidos) errores.push(`El «id_externo» «${id}» está repetido en el lote.`);

        // Correspondencia manifiesto <-> archivos seleccionados (en ambos sentidos).
        const nombres = archivos.map((archivo) => archivo.name);
        const nombresRepetidos = new Set(nombres.filter((nombre, i) => nombres.indexOf(nombre) !== i));
        for (const nombre of nombresRepetidos) errores.push(`Hay dos archivos seleccionados con el mismo nombre («${nombre}»).`);
        for (const nombre of referenciados) {
          if (!nombres.includes(nombre)) errores.push(`El manifiesto referencia «${nombre}», pero ese archivo no está seleccionado.`);
        }
        for (const nombre of new Set(nombres)) {
          if (!referenciados.has(nombre)) errores.push(`El archivo «${nombre}» no está referenciado por ningún ítem del manifiesto.`);
        }

        manifiesto = { fuente: fuenteCodigo ?? '', items: items as ItemManifiesto[] };
      }
    }
  }

  if (archivos.length === 0 && texto) errores.push('Adjunte los archivos de los resultados (PDF, JPG o PNG).');

  for (const archivo of archivos) {
    const problema = validarArchivoCliente(archivo);
    if (problema) errores.push(`Archivo «${archivo.name}»: ${problema}`);
  }

  if (totalBytes > MAX_BYTES_POR_PETICION) {
    errores.push(
      `Los archivos suman ${formatearTamano(totalBytes)} y la petición admite como máximo ${formatearTamano(MAX_BYTES_POR_PETICION)}. Divida el lote.`,
    );
  } else if (totalBytes > AVISO_BYTES_POR_PETICION) {
    avisos.push(
      `Los archivos suman ${formatearTamano(totalBytes)}. Con envíos tan grandes la subida puede tardar o fallar: considere dividir el lote en envíos más pequeños.`,
    );
  }

  const limitados = errores.length > MAX_MENSAJES
    ? [...errores.slice(0, MAX_MENSAJES), `… y ${errores.length - MAX_MENSAJES} problema(s) más.`]
    : errores;
  return { manifiesto: limitados.length ? null : manifiesto, errores: limitados, avisos, items: cantidad, totalBytes };
}

/** Lee un archivo `.json` seleccionado por el usuario como texto. */
export function leerArchivoComoTexto(archivo: File): Promise<string> {
  if (typeof archivo.text === 'function') return archivo.text();
  return new Promise<string>((resolver, rechazar) => {
    const lector = new FileReader();
    lector.onload = () => resolver(String(lector.result ?? ''));
    lector.onerror = () => rechazar(lector.error);
    lector.readAsText(archivo);
  });
}

/**
 * Arma el manifiesto de un reintento: solo los ítems en `ERROR` elegidos, tomados del manifiesto original, con
 * `nombre_archivo` apuntando al archivo corregido que adjuntó el usuario.
 */
export function armarManifiestoReintento(
  origen: Manifiesto,
  fuenteCodigo: string,
  correcciones: ReadonlyMap<string, File>,
): { manifiesto: Manifiesto; archivos: File[]; faltantes: string[] } {
  const items: ItemManifiesto[] = [];
  const archivos: File[] = [];
  const faltantes: string[] = [];
  for (const [idExterno, archivo] of correcciones) {
    const base = origen.items.find((item) => item.id_externo === idExterno);
    if (!base) {
      faltantes.push(idExterno);
      continue;
    }
    items.push({ ...base, nombre_archivo: archivo.name });
    archivos.push(archivo);
  }
  return { manifiesto: { fuente: fuenteCodigo, items }, archivos, faltantes };
}
