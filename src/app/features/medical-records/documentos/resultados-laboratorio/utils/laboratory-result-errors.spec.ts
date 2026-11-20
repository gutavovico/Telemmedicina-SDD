import { HttpErrorResponse } from '@angular/common/http';
import { describe, expect, it } from 'vitest';
import { MENSAJES_POR_CODIGO, interpretarErrorResultado, normalizarErrorConBlob } from './laboratory-result-errors';

function http(status: number, cuerpo: unknown): HttpErrorResponse {
  return new HttpErrorResponse({ status, error: cuerpo, statusText: 'x' });
}

describe('interpretarErrorResultado', () => {
  it('traduce cada código de dominio del contrato y lo asocia a su campo', () => {
    const casos: Array<[string, string]> = [
      ['ARCHIVO_TIPO_NO_PERMITIDO', 'archivo'],
      ['ARCHIVO_FIRMA_INVALIDA', 'archivo'],
      ['ARCHIVO_TAMANO_EXCEDIDO', 'archivo'],
      ['ARCHIVO_VACIO', 'archivo'],
      ['RESULTADO_DUPLICADO', 'archivo'],
      ['PACIENTE_NO_ENCONTRADO', 'id_paciente'],
      ['EXAMEN_NO_ENCONTRADO', 'codigo_examen'],
      ['ORDEN_NO_ENCONTRADA', 'id_orden'],
      ['ORDEN_PACIENTE_NO_COINCIDE', 'id_orden'],
      ['ORDEN_NO_FIRMADA', 'id_orden'],
      ['ORDEN_SIN_EXAMEN', 'id_orden'],
    ];
    for (const [codigo, campo] of casos) {
      const r = interpretarErrorResultado(http(422, { detail: { codigo, mensaje: 'texto del servidor' } }));
      expect(r.codigo).toBe(codigo);
      expect(r.mensaje).toBe((MENSAJES_POR_CODIGO as Record<string, string>)[codigo]);
      expect(r.campos[campo]).toBe(r.mensaje);
    }
  });

  it('códigos sin campo asociado no marcan ningún control', () => {
    for (const codigo of ['ESTADO_NO_PERMITIDO', 'RESULTADO_NO_ENCONTRADO', 'ARCHIVO_NO_ENCONTRADO', 'ALMACENAMIENTO_FALLIDO']) {
      const r = interpretarErrorResultado(http(409, { detail: { codigo, mensaje: 'x' } }));
      expect(r.campos).toEqual({});
      expect(r.mensaje).toBe((MENSAJES_POR_CODIGO as Record<string, string>)[codigo]);
    }
  });

  it('un código desconocido usa el mensaje del servidor', () => {
    const r = interpretarErrorResultado(http(409, { detail: { codigo: 'NUEVO_CODIGO', mensaje: 'Mensaje del servidor.' } }));
    expect(r.mensaje).toBe('Mensaje del servidor.');
    expect(r.codigo).toBe('NUEVO_CODIGO');
  });

  it('interpreta la forma de lista de validación de FastAPI', () => {
    const r = interpretarErrorResultado(
      http(422, {
        detail: [
          { type: 'value_error', loc: ['body', 'fecha_realizacion'], msg: 'La fecha de realización no puede ser posterior a la fecha actual.' },
          { type: 'missing', loc: ['body', 'laboratorio_origen'], msg: 'Field required' },
        ],
      }),
    );
    expect(r.campos['fecha_realizacion']).toContain('posterior');
    expect(r.campos['laboratorio_origen']).toBe('Field required');
    expect(r.mensaje).toContain('fecha de realización');
    expect(r.mensaje).toContain('laboratorio de origen');
    expect(r.codigo).toBeNull();
  });

  it('interpreta detail en texto según el estado', () => {
    expect(
      interpretarErrorResultado(http(403, { detail: "Permiso denegado. Se requiere el permiso 'lab_results:create'." })).mensaje,
    ).toContain('lab_results:create');
    expect(interpretarErrorResultado(http(401, { detail: 'No autenticado' })).mensaje).toContain('sesión expiró');
    expect(interpretarErrorResultado(http(400, { detail: 'Texto del servidor' })).mensaje).toBe('Texto del servidor');
  });

  it('cubre estados sin cuerpo útil', () => {
    expect(interpretarErrorResultado(http(0, null)).mensaje).toContain('conexión');
    expect(interpretarErrorResultado(http(401, null)).mensaje).toContain('sesión');
    expect(interpretarErrorResultado(http(403, null)).mensaje).toContain('permiso');
    expect(interpretarErrorResultado(http(404, null)).mensaje).toContain('No se encontró');
    expect(interpretarErrorResultado(http(500, null)).mensaje).toContain('servidor');
    expect(interpretarErrorResultado(http(418, null)).mensaje).toContain('No se pudo');
  });

  it('un error que no es HTTP da un mensaje genérico', () => {
    expect(interpretarErrorResultado(new Error('x')).mensaje).toContain('inesperado');
  });
});

describe('normalizarErrorConBlob', () => {
  it('convierte el Blob de un error de descarga en el JSON del servidor', async () => {
    const blob = new Blob([JSON.stringify({ detail: { codigo: 'RESULTADO_NO_ENCONTRADO', mensaje: 'x' } })], {
      type: 'application/json',
    });
    const normalizado = await normalizarErrorConBlob(http(404, blob));
    const r = interpretarErrorResultado(normalizado);
    expect(r.codigo).toBe('RESULTADO_NO_ENCONTRADO');
    expect(r.status).toBe(404);
  });

  it('si el Blob no es JSON conserva el estado y deja el cuerpo vacío', async () => {
    const normalizado = await normalizarErrorConBlob(http(500, new Blob(['<html>'])));
    expect(normalizado.status).toBe(500);
    expect(interpretarErrorResultado(normalizado).mensaje).toContain('servidor');
  });

  it('un error que no trae Blob se devuelve igual', async () => {
    const original = http(403, { detail: 'x' });
    expect(await normalizarErrorConBlob(original)).toBe(original);
  });
});
