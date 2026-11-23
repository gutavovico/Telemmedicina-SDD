import {
  FuenteLaboratorio,
  FuenteLaboratorioListResponse,
  ItemManifiesto,
  ItemSincronizacion,
  Manifiesto,
  Sincronizacion,
  SincronizacionListResponse,
  SincronizacionResumen,
} from '../models/laboratory-sync.models';

/** Datos de prueba derivados del contrato (solo se usan en pruebas unitarias). */
export function fuenteDemo(cambios: Partial<FuenteLaboratorio> = {}): FuenteLaboratorio {
  return {
    id_fuente: 2,
    codigo: 'LAB-CENTRAL',
    nombre: 'Laboratorio Central S.R.L.',
    activa: 'SI',
    created_at: '2026-11-18T14:00:00Z',
    updated_at: '2026-11-18T14:00:00Z',
    ...cambios,
  };
}

export function listaFuentesDemo(
  items: FuenteLaboratorio[],
  cambios: Partial<FuenteLaboratorioListResponse> = {},
): FuenteLaboratorioListResponse {
  return { items, total: items.length, page: 1, page_size: 10, total_pages: 1, ...cambios };
}

export function itemManifiestoDemo(idExterno: string, cambios: Partial<ItemManifiesto> = {}): ItemManifiesto {
  return {
    id_externo: idExterno,
    ci: '1234567',
    complemento: '',
    codigo_examen: 'HEMOGRAMA',
    laboratorio_origen: 'Laboratorio Central S.R.L.',
    fecha_realizacion: '2026-11-10',
    nombre_archivo: `${idExterno}.pdf`,
    id_orden: null,
    observaciones: null,
    ...cambios,
  };
}

export function manifiestoDemo(idsExternos: string[] = ['EXT-1'], fuente = 'LAB-CENTRAL'): Manifiesto {
  return { fuente, items: idsExternos.map((id) => itemManifiestoDemo(id)) };
}

/** Archivo de prueba; `tamano` fija `size` sin crear el contenido real. */
export function archivoDemo(nombre: string, tamano = 2048, tipo = 'application/pdf'): File {
  const archivo = new File(['%PDF-1.4'], nombre, { type: tipo });
  Object.defineProperty(archivo, 'size', { value: tamano });
  return archivo;
}

export function itemSyncDemo(idExterno: string, cambios: Partial<ItemSincronizacion> = {}): ItemSincronizacion {
  return {
    id_externo: idExterno,
    resultado: 'INCORPORADO',
    id_resultado: 15,
    codigo_error: null,
    detalle: null,
    intento: 1,
    ...cambios,
  };
}

export function resumenSyncDemo(cambios: Partial<SincronizacionResumen> = {}): SincronizacionResumen {
  return {
    id_sincronizacion: 31,
    id_fuente: 2,
    fuente_codigo: 'LAB-CENTRAL',
    tipo: 'LOTE',
    estado: 'COMPLETADA_CON_ERRORES',
    total_items: 4,
    incorporados: 1,
    pendientes: 1,
    duplicados: 1,
    con_error: 1,
    reintentos: 0,
    id_usuario: 2,
    proceso: null,
    iniciado_en: '2026-11-18T14:10:00Z',
    finalizado_en: '2026-11-18T14:10:03Z',
    ...cambios,
  };
}

/** Informe del ejemplo del contrato 2.8: un ítem de cada resultado. */
export function syncDemo(cambios: Partial<Sincronizacion> = {}): Sincronizacion {
  return {
    ...resumenSyncDemo(),
    items: [
      itemSyncDemo('LAB-2026-000123', { resultado: 'INCORPORADO', id_resultado: 15 }),
      itemSyncDemo('LAB-2026-000124', { resultado: 'PENDIENTE_REVISION', id_resultado: 16, detalle: 'PACIENTE_NO_ENCONTRADO' }),
      itemSyncDemo('LAB-2026-000100', { resultado: 'DUPLICADO', id_resultado: 9 }),
      itemSyncDemo('LAB-2026-000125', {
        resultado: 'ERROR', id_resultado: null, codigo_error: 'ARCHIVO_TIPO_NO_PERMITIDO', detalle: 'Extensión .exe no permitida',
      }),
    ],
    ...cambios,
  };
}

export function listaSyncDemo(
  items: SincronizacionResumen[],
  cambios: Partial<SincronizacionListResponse> = {},
): SincronizacionListResponse {
  return { items, total: items.length, page: 1, page_size: 10, total_pages: 1, ...cambios };
}
