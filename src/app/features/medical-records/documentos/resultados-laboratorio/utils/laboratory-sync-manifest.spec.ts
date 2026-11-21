import { describe, expect, it } from 'vitest';
import { archivoDemo, itemManifiestoDemo, manifiestoDemo } from '../testing/lab-sync.testing';
import { armarManifiestoReintento, validarLote } from './laboratory-sync-manifest';

const AHORA = new Date(2026, 10, 19); // 2026-11-19 local
const MB = 1024 * 1024;

function texto(ids: string[], cambios: Record<string, unknown> = {}): string {
  return JSON.stringify({ items: ids.map((id) => itemManifiestoDemo(id)), ...cambios });
}

function archivosDe(ids: string[]): File[] {
  return ids.map((id) => archivoDemo(`${id}.pdf`));
}

function validar(t: string, archivos: File[], fuente: string | null = 'LAB-CENTRAL') {
  return validarLote(t, archivos, fuente, AHORA);
}

describe('validarLote', () => {
  it('acepta un lote válido y arma el manifiesto con la fuente elegida', () => {
    const r = validar(texto(['EXT-1', 'EXT-2']), archivosDe(['EXT-1', 'EXT-2']));
    expect(r.errores).toEqual([]);
    expect(r.items).toBe(2);
    expect(r.manifiesto?.fuente).toBe('LAB-CENTRAL');
    expect(r.manifiesto?.items.map((i) => i.id_externo)).toEqual(['EXT-1', 'EXT-2']);
    expect(r.totalBytes).toBe(4096);
  });

  it('acepta que el manifiesto traiga la misma fuente (sin distinguir mayúsculas)', () => {
    const r = validar(texto(['EXT-1'], { fuente: 'lab-central' }), archivosDe(['EXT-1']));
    expect(r.errores).toEqual([]);
  });

  it('rechaza una fuente del manifiesto distinta de la seleccionada y exige elegir fuente', () => {
    expect(validar(texto(['EXT-1'], { fuente: 'OTRA' }), archivosDe(['EXT-1'])).errores.join(' ')).toContain('no coincide');
    expect(validar(texto(['EXT-1']), archivosDe(['EXT-1']), null).errores).toContain('Seleccione la fuente de laboratorio.');
  });

  it.each([
    ['vacío', '', 'Cargue o pegue el manifiesto'],
    ['no es JSON', '{no es json', 'no es un JSON válido'],
    ['raíz no es objeto', '[1,2]', 'objeto JSON'],
    ['sin items', '{}', '«items» como una lista'],
    ['items no es lista', '{"items": {}}', '«items» como una lista'],
    ['lote sin ítems', '{"items": []}', 'no tiene ítems'],
  ])('rechaza un manifiesto %s', (_nombre, entrada, mensaje) => {
    const r = validar(entrada, []);
    expect(r.manifiesto).toBeNull();
    expect(r.errores.join(' ')).toContain(mensaje);
  });

  it('rechaza más de 50 ítems y acepta exactamente 50', () => {
    const cincuenta = Array.from({ length: 50 }, (_, i) => `EXT-${i}`);
    expect(validar(texto(cincuenta), archivosDe(cincuenta)).errores).toEqual([]);
    const cincuentaYUno = [...cincuenta, 'EXT-50'];
    const r = validar(texto(cincuentaYUno), archivosDe(cincuentaYUno));
    expect(r.manifiesto).toBeNull();
    expect(r.errores.join(' ')).toContain('máximo 50 ítems');
  });

  it('detecta id_externo repetidos', () => {
    const t = JSON.stringify({ items: [itemManifiestoDemo('EXT-1'), itemManifiestoDemo('EXT-1', { nombre_archivo: 'b.pdf' })] });
    const r = validar(t, [archivoDemo('EXT-1.pdf'), archivoDemo('b.pdf')]);
    expect(r.errores.join(' ')).toContain('«EXT-1» está repetido');
  });

  it.each(['id_clinica', 'tenant_id'])('rechaza %s en la raíz y en un ítem', (campo) => {
    expect(validar(texto(['EXT-1'], { [campo]: 1 }), archivosDe(['EXT-1'])).errores.join(' ')).toContain(`«${campo}»`);
    const t = JSON.stringify({ items: [{ ...itemManifiestoDemo('EXT-1'), [campo]: 1 }] });
    expect(validar(t, archivosDe(['EXT-1'])).errores.join(' ')).toContain(`«${campo}»`);
  });

  it.each([
    ['id_externo', ''],
    ['ci', ''],
    ['ci', 'x'.repeat(21)],
    ['codigo_examen', ''],
    ['laboratorio_origen', ''],
    ['nombre_archivo', ''],
    ['complemento', 'C'.repeat(11)],
    ['fecha_realizacion', '10/11/2026'],
    ['fecha_realizacion', '2999-01-01'],
    ['id_orden', 0],
    ['id_orden', 1.5],
    ['observaciones', 'o'.repeat(2001)],
  ])('rechaza el campo %s con el valor inválido', (campo, valor) => {
    const t = JSON.stringify({ items: [{ ...itemManifiestoDemo('EXT-1'), [campo]: valor }] });
    const r = validar(t, [archivoDemo('EXT-1.pdf')]);
    expect(r.manifiesto).toBeNull();
    expect(r.errores.length).toBeGreaterThan(0);
  });

  it('rechaza un campo obligatorio ausente', () => {
    const { ci: _ci, ...sinCi } = itemManifiestoDemo('EXT-1');
    const r = validar(JSON.stringify({ items: [sinCi] }), archivosDe(['EXT-1']));
    expect(r.errores.join(' ')).toContain('«ci» es obligatorio');
  });

  it('exige un archivo seleccionado por cada nombre_archivo y viceversa', () => {
    const r = validar(texto(['EXT-1', 'EXT-2']), [archivoDemo('EXT-1.pdf'), archivoDemo('sobrante.pdf')]);
    const mensajes = r.errores.join(' | ');
    expect(mensajes).toContain('referencia «EXT-2.pdf», pero ese archivo no está seleccionado');
    expect(mensajes).toContain('«sobrante.pdf» no está referenciado');
  });

  it('rechaza dos archivos seleccionados con el mismo nombre', () => {
    const r = validar(texto(['EXT-1']), [archivoDemo('EXT-1.pdf'), archivoDemo('EXT-1.pdf')]);
    expect(r.errores.join(' ')).toContain('mismo nombre («EXT-1.pdf»)');
  });

  it('permite que varios ítems referencien el mismo archivo', () => {
    const t = JSON.stringify({ items: [itemManifiestoDemo('A', { nombre_archivo: 'c.pdf' }), itemManifiestoDemo('B', { nombre_archivo: 'c.pdf' })] });
    expect(validar(t, [archivoDemo('c.pdf')]).errores).toEqual([]);
  });

  it('pide adjuntar archivos cuando no hay ninguno', () => {
    expect(validar(texto(['EXT-1']), []).errores.join(' ')).toContain('Adjunte los archivos');
  });

  it.each([
    ['virus.exe', 100, 'PDF, JPG o PNG'],
    ['vacio.pdf', 0, 'vacío'],
    ['grande.pdf', 10 * MB + 1, '10 MB'],
  ])('valida cada archivo: %s', (nombre, tamano, mensaje) => {
    const t = JSON.stringify({ items: [itemManifiestoDemo('EXT-1', { nombre_archivo: nombre })] });
    const r = validar(t, [archivoDemo(nombre, tamano)]);
    expect(r.errores.join(' ')).toContain(mensaje);
  });

  it('acepta PDF, JPG, JPEG y PNG de hasta 10 MB exactos', () => {
    const nombres = ['a.pdf', 'b.JPG', 'c.jpeg', 'd.png'];
    const t = JSON.stringify({ items: nombres.map((n, i) => itemManifiestoDemo(`E${i}`, { nombre_archivo: n })) });
    expect(validar(t, nombres.map((n) => archivoDemo(n, 10 * MB))).errores).toEqual([]);
  });

  it('rechaza más de 100 MB en total y avisa por encima de 50 MB', () => {
    const ids = Array.from({ length: 11 }, (_, i) => `E${i}`);
    const grande = (tamano: number) => ids.map((id) => archivoDemo(`${id}.pdf`, tamano));
    const sobrepasa = validar(texto(ids), grande(10 * MB)); // 110 MB
    expect(sobrepasa.errores.join(' ')).toContain('admite como máximo 100.0 MB');

    const seis = ids.slice(0, 6);
    const aviso = validar(texto(seis), seis.map((id) => archivoDemo(`${id}.pdf`, 10 * MB))); // 60 MB
    expect(aviso.errores).toEqual([]);
    expect(aviso.avisos.join(' ')).toContain('dividir el lote');
    expect(aviso.manifiesto).not.toBeNull();

    const poco = validar(texto(['E0']), [archivoDemo('E0.pdf', 10 * MB)]);
    expect(poco.avisos).toEqual([]);
  });

  it('rechaza un manifiesto de más de 1 MB', () => {
    const r = validar(texto(['EXT-1'], { relleno: 'x'.repeat(MB + 10) }), archivosDe(['EXT-1']));
    expect(r.errores.join(' ')).toContain('supera 1 MB');
  });

  it('limita la cantidad de mensajes devueltos', () => {
    const items = Array.from({ length: 30 }, (_, i) => ({ ...itemManifiestoDemo(`E${i}`), ci: '' }));
    const r = validar(JSON.stringify({ items }), []);
    expect(r.errores.length).toBeLessThanOrEqual(16);
    expect(r.errores[r.errores.length - 1]).toContain('más');
  });
});

describe('armarManifiestoReintento', () => {
  it('toma solo los ítems elegidos del manifiesto original y apunta al archivo corregido', () => {
    const origen = manifiestoDemo(['A', 'B', 'C']);
    const corregido = archivoDemo('B-corregido.pdf');
    const r = armarManifiestoReintento(origen, 'LAB-CENTRAL', new Map([['B', corregido]]));
    expect(r.manifiesto.fuente).toBe('LAB-CENTRAL');
    expect(r.manifiesto.items).toHaveLength(1);
    expect(r.manifiesto.items[0]).toMatchObject({ id_externo: 'B', ci: '1234567', nombre_archivo: 'B-corregido.pdf' });
    expect(r.archivos).toEqual([corregido]);
    expect(r.faltantes).toEqual([]);
    expect(origen.items[1].nombre_archivo).toBe('B.pdf'); // no muta el original
  });

  it('informa los ítems que no figuran en el manifiesto original', () => {
    const r = armarManifiestoReintento(manifiestoDemo(['A']), 'LAB-CENTRAL', new Map([['Z', archivoDemo('z.pdf')]]));
    expect(r.faltantes).toEqual(['Z']);
    expect(r.manifiesto.items).toEqual([]);
    expect(r.archivos).toEqual([]);
  });
});
