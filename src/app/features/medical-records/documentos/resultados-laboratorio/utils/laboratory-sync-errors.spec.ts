import { HttpErrorResponse } from '@angular/common/http';
import { describe, expect, it } from 'vitest';
import { itemSyncDemo } from '../testing/lab-sync.testing';
import { MENSAJES_POR_CODIGO } from './laboratory-result-errors';
import { interpretarErrorSincronizacion, mensajeDeItem } from './laboratory-sync-errors';

function errorHttp(status: number, cuerpo: unknown): HttpErrorResponse {
  return new HttpErrorResponse({ status, error: cuerpo, statusText: 'x' });
}

describe('interpretarErrorSincronizacion', () => {
  it.each([
    ['FUENTE_DUPLICADA', 409],
    ['FUENTE_NO_ENCONTRADA', 404],
    ['FUENTE_INACTIVA', 409],
    ['SINCRONIZACION_NO_ENCONTRADA', 404],
    ['CONTENIDO_DISTINTO', 409],
    ['ERROR_INTERNO', 500],
    ['ARCHIVO_AUSENTE', 422],
  ])('el código %s tiene un mensaje en español', (codigo, status) => {
    const r = interpretarErrorSincronizacion(errorHttp(status, { detail: { codigo, mensaje: 'texto en servidor' } }));
    expect(r.codigo).toBe(codigo);
    expect(r.mensaje).toBe((MENSAJES_POR_CODIGO as Record<string, string>)[codigo]);
    expect(r.mensaje).not.toBe('texto en servidor');
  });

  it('FUENTE_DUPLICADA se asocia al campo código', () => {
    const r = interpretarErrorSincronizacion(errorHttp(409, { detail: { codigo: 'FUENTE_DUPLICADA', mensaje: 'x' } }));
    expect(Object.keys(r.campos)).toEqual(['codigo']);
    expect(r.mensaje).toContain('Ya existe una fuente');
  });

  it('LOTE_INVALIDO y ITEM_NO_REINTENTABLE agregan el detalle del servidor', () => {
    const lote = interpretarErrorSincronizacion(
      errorHttp(422, { detail: { codigo: 'LOTE_INVALIDO', mensaje: 'El lote admite como máximo 50 ítems.' } }),
    );
    expect(lote.mensaje).toContain('El lote no es válido');
    expect(lote.mensaje).toContain('máximo 50 ítems');
    const item = interpretarErrorSincronizacion(
      errorHttp(422, { detail: { codigo: 'ITEM_NO_REINTENTABLE', mensaje: 'Solo se pueden reintentar ítems en ERROR: EXT-1' } }),
    );
    expect(item.mensaje).toContain('EXT-1');
  });

  it('acepta la forma de lista de validación (422 de FastAPI)', () => {
    const r = interpretarErrorSincronizacion(
      errorHttp(422, { detail: [{ type: 'string_too_short', loc: ['body', 'codigo'], msg: 'String should have at least 2 characters' }] }),
    );
    expect(r.codigo).toBeNull();
    expect(r.campos['codigo']).toContain('at least 2');
    expect(r.mensaje).toContain('código');
  });

  it('acepta el texto plano de 401, 403 y otros', () => {
    expect(interpretarErrorSincronizacion(errorHttp(401, { detail: 'No autenticado' })).mensaje).toContain('sesión expiró');
    expect(interpretarErrorSincronizacion(errorHttp(403, { detail: "Permiso denegado. Se requiere el permiso 'lab_results:sync'." })).mensaje).toContain('lab_results:sync');
  });

  it('traduce el 400 de texto plano de Starlette por un manifiesto de más de 1 MB', () => {
    const r = interpretarErrorSincronizacion(errorHttp(400, { detail: 'Part exceeded maximum size of 1024KB.' }));
    expect(r.mensaje).toContain('manifiesto supera 1 MB');
    expect(r.codigo).toBeNull();
  });

  it('un 400 de texto con otro contenido se muestra tal cual', () => {
    expect(interpretarErrorSincronizacion(errorHttp(400, { detail: 'Solicitud incorrecta' })).mensaje).toBe('Solicitud incorrecta');
  });

  it('sin conexión y errores que no son HTTP', () => {
    expect(interpretarErrorSincronizacion(errorHttp(0, null)).mensaje).toContain('No hay conexión');
    expect(interpretarErrorSincronizacion(new Error('x')).mensaje).toContain('inesperado');
  });
});

describe('mensajeDeItem', () => {
  const motivos = { PACIENTE_NO_ENCONTRADO: 'No se encontró un paciente con esa CI.' };

  it('ERROR: código con su mensaje en español', () => {
    const r = mensajeDeItem(itemSyncDemo('E', { resultado: 'ERROR', codigo_error: 'ARCHIVO_TIPO_NO_PERMITIDO', detalle: 'Extensión .exe no permitida' }));
    expect(r.codigo).toBe('ARCHIVO_TIPO_NO_PERMITIDO');
    expect(r.mensaje).toBe('El archivo debe ser PDF, JPG o PNG.');
  });

  it('ERROR con un código desconocido muestra el detalle del servidor', () => {
    const r = mensajeDeItem(itemSyncDemo('E', { resultado: 'ERROR', codigo_error: 'CODIGO_NUEVO', detalle: 'Algo pasó' }));
    expect(r).toEqual({ codigo: 'CODIGO_NUEVO', mensaje: 'Algo pasó' });
  });

  it('PENDIENTE_REVISION: motivo traducido', () => {
    const r = mensajeDeItem(itemSyncDemo('E', { resultado: 'PENDIENTE_REVISION', detalle: 'PACIENTE_NO_ENCONTRADO' }), motivos);
    expect(r).toEqual({ codigo: 'PACIENTE_NO_ENCONTRADO', mensaje: 'No se encontró un paciente con esa CI.' });
  });

  it('DUPLICADO e INCORPORADO', () => {
    expect(mensajeDeItem(itemSyncDemo('E', { resultado: 'DUPLICADO' })).mensaje).toContain('Ya estaba registrado');
    expect(mensajeDeItem(itemSyncDemo('E'))).toEqual({ codigo: null, mensaje: null });
  });
});
