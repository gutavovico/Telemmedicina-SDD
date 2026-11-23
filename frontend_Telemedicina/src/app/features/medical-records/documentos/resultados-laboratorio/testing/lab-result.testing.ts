import { Paciente } from '../../../../../core/models/patient.models';
import {
  ResultadoLaboratorio,
  ResultadoLaboratorioListResponse,
  ResultadoLaboratorioResumen,
} from '../models/laboratory-result.models';

/** Datos de prueba derivados del contrato (solo se usan en pruebas unitarias). */
export function resumenDemo(cambios: Partial<ResultadoLaboratorioResumen> = {}): ResultadoLaboratorioResumen {
  return {
    id_resultado: 15,
    id_clinica: 1,
    estado: 'INCORPORADO',
    origen: 'MANUAL',
    id_paciente: 10,
    paciente_nombre: 'Carlos Mamani',
    id_orden: null,
    id_examen: 3,
    codigo_examen: 'HEMOGRAMA',
    nombre_examen: 'Hemograma completo',
    laboratorio_origen: 'Laboratorio Central',
    fecha_realizacion: '2026-11-10',
    nombre_archivo: 'hemograma.pdf',
    content_type: 'application/pdf',
    tamano_bytes: 182340,
    hash_archivo: 'a'.repeat(64),
    id_documento: 88,
    id_fuente: null,
    fuente_codigo: null,
    id_externo: null,
    id_sincronizacion: null,
    motivo_pendiente: null,
    registrado_por: 4,
    registrado_por_nombre: 'Recepción Central',
    proceso: null,
    registrado_en: '2026-11-18T14:05:00Z',
    resuelto_por: null,
    resuelto_en: null,
    motivo_resolucion: null,
    ...cambios,
  };
}

export function detalleDemo(cambios: Partial<ResultadoLaboratorio> = {}): ResultadoLaboratorio {
  return {
    ...resumenDemo(),
    observaciones: 'Muestra en ayunas',
    datos_correspondencia: null,
    ...cambios,
  };
}

export function listaDemo(
  items: ResultadoLaboratorioResumen[],
  cambios: Partial<ResultadoLaboratorioListResponse> = {},
): ResultadoLaboratorioListResponse {
  return { items, total: items.length, page: 1, page_size: 10, total_pages: 1, ...cambios };
}

export function pacienteDemo(cambios: Partial<Paciente> = {}): Paciente {
  return {
    id_paciente: 10,
    nombres: 'Carlos',
    apellidos: 'Mamani',
    ci: '1234567',
    fecha_nacimiento: '1990-01-01',
    genero: 'M',
    telefono: '70000000',
    estado: 'ACTIVO',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    ...cambios,
  };
}

/** Permisos configurables para sustituir a `LaboratoryResultAccessService` en las pruebas de pantallas. */
export interface PermisosFalsos {
  crear?: boolean;
  leer?: boolean;
  revisar?: boolean;
  sincronizar?: boolean;
  descargar?: boolean;
}

export function accesoFalso(permisos: PermisosFalsos) {
  return {
    puedeCrear: () => !!permisos.crear,
    puedeLeer: () => !!permisos.leer,
    puedeRevisar: () => !!permisos.revisar,
    puedeSincronizar: () => !!permisos.sincronizar,
    puedeDescargar: () => !!permisos.descargar,
  };
}
