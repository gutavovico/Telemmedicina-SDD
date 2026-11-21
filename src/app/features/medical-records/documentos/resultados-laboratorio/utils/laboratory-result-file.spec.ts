import { describe, expect, it } from 'vitest';
import {
  TAMANO_MAXIMO_BYTES,
  esFechaFutura,
  formatearTamano,
  hoyIso,
  nombreDesdeContentDisposition,
  validarArchivoCliente,
} from './laboratory-result-file';

function archivo(nombre: string, tamano: number): File {
  const f = new File(['x'], nombre);
  Object.defineProperty(f, 'size', { value: tamano });
  return f;
}

describe('validarArchivoCliente', () => {
  it('exige seleccionar un archivo', () => {
    expect(validarArchivoCliente(null)).toContain('Seleccione');
    expect(validarArchivoCliente(undefined)).toContain('Seleccione');
  });

  it.each(['informe.pdf', 'foto.JPG', 'foto.jpeg', 'imagen.PNG'])('acepta %s', (nombre) => {
    expect(validarArchivoCliente(archivo(nombre, 1000))).toBeNull();
  });

  it.each(['programa.exe', 'documento.docx', 'sin_extension', '.pdf'])('rechaza la extensión de %s', (nombre) => {
    expect(validarArchivoCliente(archivo(nombre, 1000))).toBe('El archivo debe ser PDF, JPG o PNG.');
  });

  it('rechaza un archivo vacío', () => {
    expect(validarArchivoCliente(archivo('vacio.pdf', 0))).toBe('El archivo está vacío.');
  });

  it('acepta exactamente 10 MB y rechaza un byte más', () => {
    expect(validarArchivoCliente(archivo('max.pdf', TAMANO_MAXIMO_BYTES))).toBeNull();
    expect(validarArchivoCliente(archivo('max.pdf', TAMANO_MAXIMO_BYTES + 1))).toContain('10 MB');
  });
});

describe('fechas', () => {
  const ahora = new Date(2026, 10, 18, 22, 30); // 18-nov-2026 22:30 hora local

  it('hoyIso usa la fecha local', () => {
    expect(hoyIso(ahora)).toBe('2026-11-18');
  });

  it('detecta fechas futuras y acepta hoy y el pasado', () => {
    expect(esFechaFutura('2026-11-19', ahora)).toBe(true);
    expect(esFechaFutura('2026-11-18', ahora)).toBe(false);
    expect(esFechaFutura('2026-01-01', ahora)).toBe(false);
    expect(esFechaFutura('', ahora)).toBe(false);
  });
});

describe('formatearTamano', () => {
  it('usa B, KB y MB', () => {
    expect(formatearTamano(512)).toBe('512 B');
    expect(formatearTamano(2048)).toBe('2.0 KB');
    expect(formatearTamano(5 * 1024 * 1024)).toBe('5.0 MB');
  });
});

describe('nombreDesdeContentDisposition', () => {
  it('prefiere filename* codificado', () => {
    expect(
      nombreDesdeContentDisposition(`attachment; filename="an_lisis.pdf"; filename*=UTF-8''an%C3%A1lisis.pdf`, 'x'),
    ).toBe('análisis.pdf');
  });

  it('usa filename simple, y el respaldo cuando no hay cabecera', () => {
    expect(nombreDesdeContentDisposition('attachment; filename="hemograma.pdf"', 'x')).toBe('hemograma.pdf');
    expect(nombreDesdeContentDisposition(null, 'resultado-5')).toBe('resultado-5');
    expect(nombreDesdeContentDisposition('attachment', 'resultado-5')).toBe('resultado-5');
  });
});
