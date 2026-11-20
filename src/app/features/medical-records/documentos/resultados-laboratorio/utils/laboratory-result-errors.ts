import { HttpErrorResponse } from '@angular/common/http';
import {
  CodigoErrorResultado,
  ErrorDominioDetalle,
  ErrorResultadoInterpretado,
  ErrorValidacionDetalle,
} from '../models/laboratory-result.models';

/** Mensajes en español para los códigos de dominio del contrato. */
export const MENSAJES_POR_CODIGO: Record<CodigoErrorResultado, string> = {
  ARCHIVO_TIPO_NO_PERMITIDO: 'El archivo debe ser PDF, JPG o PNG.',
  ARCHIVO_FIRMA_INVALIDA: 'El contenido del archivo no corresponde a su extensión o a su tipo declarado.',
  ARCHIVO_TAMANO_EXCEDIDO: 'El archivo supera el tamaño máximo de 10 MB.',
  ARCHIVO_VACIO: 'El archivo está vacío.',
  ARCHIVO_NO_ENCONTRADO: 'El archivo de este resultado no se encuentra en el almacenamiento.',
  PACIENTE_NO_ENCONTRADO: 'El paciente no existe en su clínica.',
  EXAMEN_NO_ENCONTRADO: 'El estudio no existe, está inactivo o no pertenece al catálogo de su clínica.',
  ORDEN_NO_ENCONTRADA: 'La orden de laboratorio no existe en su clínica.',
  ORDEN_PACIENTE_NO_COINCIDE: 'La orden pertenece a otro paciente.',
  ORDEN_NO_FIRMADA: 'La orden de laboratorio todavía no está firmada.',
  ORDEN_SIN_EXAMEN: 'La orden no incluye el estudio indicado.',
  RESULTADO_DUPLICADO: 'Ya existe un resultado incorporado con este mismo archivo para el paciente.',
  RESULTADO_NO_ENCONTRADO: 'El resultado no existe o no está disponible para usted.',
  ESTADO_NO_PERMITIDO: 'El resultado no está en un estado que permita esta operación.',
  ALMACENAMIENTO_FALLIDO: 'No se pudo guardar el archivo. Intente nuevamente.',
  ARCHIVO_AUSENTE: 'El archivo indicado en el manifiesto no vino en el envío.',
  FUENTE_NO_ENCONTRADA: 'La fuente de laboratorio no existe en su clínica.',
  FUENTE_INACTIVA: 'La fuente de laboratorio está inactiva. Actívela para poder importar o reintentar.',
  FUENTE_DUPLICADA: 'Ya existe una fuente con ese código en su clínica.',
  LOTE_INVALIDO: 'El lote no es válido y no se procesó ningún ítem.',
  CONTENIDO_DISTINTO: 'Este identificador ya está registrado con un archivo de contenido distinto; el resultado original no se modificó.',
  ITEM_NO_REINTENTABLE: 'Solo se pueden reintentar ítems en ERROR de esta sincronización. No se procesó ningún ítem.',
  SINCRONIZACION_NO_ENCONTRADA: 'La sincronización no existe o no pertenece a su clínica.',
  ERROR_INTERNO: 'Ocurrió un error inesperado al procesar el ítem. Puede reintentarlo.',
};

/** Campo del formulario al que corresponde cada código, para mostrar el error junto a su control. */
const CAMPO_POR_CODIGO: Partial<Record<CodigoErrorResultado, string>> = {
  ARCHIVO_TIPO_NO_PERMITIDO: 'archivo',
  ARCHIVO_FIRMA_INVALIDA: 'archivo',
  ARCHIVO_TAMANO_EXCEDIDO: 'archivo',
  ARCHIVO_VACIO: 'archivo',
  RESULTADO_DUPLICADO: 'archivo',
  PACIENTE_NO_ENCONTRADO: 'id_paciente',
  EXAMEN_NO_ENCONTRADO: 'codigo_examen',
  ORDEN_NO_ENCONTRADA: 'id_orden',
  ORDEN_PACIENTE_NO_COINCIDE: 'id_orden',
  ORDEN_NO_FIRMADA: 'id_orden',
  ORDEN_SIN_EXAMEN: 'id_orden',
  FUENTE_DUPLICADA: 'codigo',
};

const NOMBRE_DE_CAMPO: Record<string, string> = {
  archivo: 'archivo',
  id_paciente: 'paciente',
  codigo_examen: 'estudio',
  fecha_realizacion: 'fecha de realización',
  laboratorio_origen: 'laboratorio de origen',
  id_orden: 'orden',
  observaciones: 'observaciones',
  motivo: 'motivo',
  accion: 'acción',
  codigo: 'código',
  nombre: 'nombre',
  activa: 'estado de la fuente',
  manifiesto: 'manifiesto',
};

function esObjetoDominio(detalle: unknown): detalle is ErrorDominioDetalle {
  return (
    typeof detalle === 'object' &&
    detalle !== null &&
    !Array.isArray(detalle) &&
    typeof (detalle as { codigo?: unknown }).codigo === 'string'
  );
}

function esListaValidacion(detalle: unknown): detalle is ErrorValidacionDetalle[] {
  return Array.isArray(detalle);
}

export function mensajeDeCodigo(codigo: string, mensajeServidor?: string): string {
  return (MENSAJES_POR_CODIGO as Record<string, string>)[codigo] ?? mensajeServidor ?? 'No se pudo completar la operación.';
}

/**
 * Interpreta cualquiera de las tres formas de `detail` del contrato (objeto de dominio, lista de validación
 * de FastAPI y texto) y devuelve un mensaje claro en español. Muestra siempre el error del servidor.
 */
export function interpretarErrorResultado(error: unknown): ErrorResultadoInterpretado {
  if (!(error instanceof HttpErrorResponse)) {
    return { mensaje: 'Ocurrió un error inesperado. Intente nuevamente.', codigo: null, campos: {}, status: -1 };
  }
  const status = error.status;
  if (status === 0) {
    return { mensaje: 'No hay conexión con el servidor. Verifique su red e intente nuevamente.', codigo: null, campos: {}, status };
  }
  const cuerpo = (error.error ?? null) as { detail?: unknown } | null;
  const detalle = cuerpo && typeof cuerpo === 'object' ? cuerpo.detail : undefined;

  if (esObjetoDominio(detalle)) {
    const mensaje = mensajeDeCodigo(detalle.codigo, detalle.mensaje);
    const campo = (CAMPO_POR_CODIGO as Record<string, string | undefined>)[detalle.codigo];
    return { mensaje, codigo: detalle.codigo, campos: campo ? { [campo]: mensaje } : {}, status };
  }

  if (esListaValidacion(detalle)) {
    const campos: Record<string, string> = {};
    const frases: string[] = [];
    for (const elemento of detalle) {
      const loc = Array.isArray(elemento.loc) ? elemento.loc : [];
      const campo = String(loc[loc.length - 1] ?? 'cuerpo');
      const etiqueta = NOMBRE_DE_CAMPO[campo] ?? campo;
      const texto = elemento.msg ?? 'valor no válido';
      if (!(campo in campos)) campos[campo] = texto;
      frases.push(`${etiqueta}: ${texto}`);
    }
    const mensaje = frases.length
      ? `Revise los datos ingresados. ${frases.join('. ')}.`
      : 'Revise los datos ingresados.';
    return { mensaje, codigo: null, campos, status };
  }

  if (typeof detalle === 'string' && detalle.trim()) {
    if (status === 401) {
      return { mensaje: 'Su sesión expiró. Inicie sesión nuevamente.', codigo: null, campos: {}, status };
    }
    if (status === 403) {
      return { mensaje: `No tiene permiso para esta operación. ${detalle}`, codigo: null, campos: {}, status };
    }
    return { mensaje: detalle, codigo: null, campos: {}, status };
  }

  if (status === 401) {
    return { mensaje: 'Su sesión expiró. Inicie sesión nuevamente.', codigo: null, campos: {}, status };
  }
  if (status === 403) {
    return { mensaje: 'No tiene permiso para esta operación.', codigo: null, campos: {}, status };
  }
  if (status === 404) {
    return { mensaje: 'No se encontró el recurso solicitado.', codigo: null, campos: {}, status };
  }
  if (status >= 500) {
    return { mensaje: 'El servidor no pudo completar la operación. Intente nuevamente.', codigo: null, campos: {}, status };
  }
  return { mensaje: 'No se pudo completar la operación.', codigo: null, campos: {}, status };
}

/**
 * Con `responseType: 'blob'` el cuerpo de un error llega como Blob: lo convierte de nuevo a JSON para que
 * `interpretarErrorResultado` pueda leer `detail`.
 */
export async function normalizarErrorConBlob(error: HttpErrorResponse): Promise<HttpErrorResponse> {
  if (!(error.error instanceof Blob)) return error;
  try {
    const texto = await leerBlobComoTexto(error.error);
    const cuerpo: unknown = JSON.parse(texto);
    return new HttpErrorResponse({
      error: cuerpo,
      headers: error.headers,
      status: error.status,
      statusText: error.statusText,
      url: error.url ?? undefined,
    });
  } catch {
    return new HttpErrorResponse({
      error: null,
      headers: error.headers,
      status: error.status,
      statusText: error.statusText,
      url: error.url ?? undefined,
    });
  }
}

function leerBlobComoTexto(blob: Blob): Promise<string> {
  if (typeof blob.text === 'function') return blob.text();
  return new Promise<string>((resolver, rechazar) => {
    const lector = new FileReader();
    lector.onload = () => resolver(String(lector.result ?? ''));
    lector.onerror = () => rechazar(lector.error);
    lector.readAsText(blob);
  });
}
