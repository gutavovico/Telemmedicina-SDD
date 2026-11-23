import { HttpErrorResponse } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { Subject, of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { EventoSubida } from '../../models/laboratory-sync.models';
import { LaboratorySyncService } from '../../services/laboratory-sync.service';
import { archivoDemo, fuenteDemo, itemManifiestoDemo, listaFuentesDemo, syncDemo } from '../../testing/lab-sync.testing';
import { leerManifiesto } from '../../utils/laboratory-sync-cache';
import { LaboratorySyncImport } from './laboratory-sync-import';

function errorHttp(status: number, cuerpo: unknown): HttpErrorResponse {
  return new HttpErrorResponse({ status, error: cuerpo, statusText: 'x' });
}

const TEXTO = JSON.stringify({ items: [itemManifiestoDemo('EXT-1'), itemManifiestoDemo('EXT-2')] });

describe('LaboratorySyncImport', () => {
  let fixture: ComponentFixture<LaboratorySyncImport>;
  let componente: LaboratorySyncImport;
  let listarFuentes: ReturnType<typeof vi.fn>;
  let importar: ReturnType<typeof vi.fn>;
  let navegar: ReturnType<typeof vi.spyOn>;

  const raiz = () => fixture.nativeElement as HTMLElement;
  const q = (testid: string) => raiz().querySelector(`[data-testid="${testid}"]`) as HTMLElement | null;

  function crear(): void {
    TestBed.configureTestingModule({
      providers: [provideRouter([]), { provide: LaboratorySyncService, useValue: { listarFuentes, importar } }],
    });
    fixture = TestBed.createComponent(LaboratorySyncImport);
    componente = fixture.componentInstance;
    navegar = vi.spyOn(TestBed.inject(Router), 'navigate').mockResolvedValue(true);
    fixture.detectChanges();
  }

  /** Completa un lote válido de dos ítems. */
  function completarValido(): void {
    componente.alElegirFuente('2');
    componente.alEscribirManifiesto(TEXTO);
    componente.archivos.set([archivoDemo('EXT-1.pdf'), archivoDemo('EXT-2.pdf')]);
    fixture.detectChanges();
  }

  beforeEach(() => {
    sessionStorage.clear();
    listarFuentes = vi.fn(() => of(listaFuentesDemo([fuenteDemo(), fuenteDemo({ id_fuente: 3, codigo: 'LAB-NORTE' })])));
    importar = vi.fn(() => of({ tipo: 'respuesta', sincronizacion: syncDemo() } satisfies EventoSubida));
  });

  it('pide solo las fuentes activas y las lista en el selector', () => {
    crear();
    expect(listarFuentes).toHaveBeenCalledWith({ activa: 'SI', page: 1, page_size: 100 });
    const opciones = Array.from(raiz().querySelectorAll('#fuente option')).map((o) => o.textContent?.trim());
    expect(opciones[0]).toContain('Seleccione');
    expect(opciones.slice(1)).toEqual(['LAB-CENTRAL — Laboratorio Central S.R.L.', 'LAB-NORTE — Laboratorio Central S.R.L.']);
  });

  it('preselecciona la única fuente activa', () => {
    listarFuentes.mockReturnValue(of(listaFuentesDemo([fuenteDemo()])));
    crear();
    expect(componente.fuenteCodigo()).toBe('LAB-CENTRAL');
  });

  it('sin fuentes activas muestra el aviso con el enlace a Fuentes', () => {
    listarFuentes.mockReturnValue(of(listaFuentesDemo([])));
    crear();
    expect(q('sin-fuentes')?.textContent).toContain('No hay fuentes activas');
    expect(q('sin-fuentes')?.querySelector('a')?.getAttribute('href')).toBe('/admin/resultados-laboratorio/fuentes');
  });

  it('muestra el error al cargar las fuentes', () => {
    listarFuentes.mockReturnValue(throwError(() => errorHttp(403, { detail: "Permiso denegado. Se requiere el permiso 'lab_results:sync'." })));
    crear();
    expect(q('error-fuentes')?.textContent).toContain('lab_results:sync');
  });

  it('las etiquetas están asociadas a sus controles', () => {
    crear();
    for (const id of ['fuente', 'manifiesto-archivo', 'manifiesto-texto', 'archivos']) {
      expect(raiz().querySelector(`label[for="${id}"]`), id).not.toBeNull();
      expect(raiz().querySelector(`#${id}`), id).not.toBeNull();
    }
  });

  it('valida en el cliente: manifiesto sin archivos, archivo sin ítem y JSON inválido', () => {
    crear();
    componente.alElegirFuente('2');
    componente.alEscribirManifiesto('{no es json');
    fixture.detectChanges();
    expect(q('errores-validacion')?.textContent).toContain('no es un JSON válido');

    componente.alEscribirManifiesto(TEXTO);
    componente.archivos.set([archivoDemo('EXT-1.pdf'), archivoDemo('sobrante.pdf')]);
    fixture.detectChanges();
    const texto = q('errores-validacion')?.textContent ?? '';
    expect(texto).toContain('referencia «EXT-2.pdf»');
    expect(texto).toContain('«sobrante.pdf» no está referenciado');
  });

  it('un envío inválido no llama al servicio', () => {
    crear();
    componente.alEscribirManifiesto(TEXTO);
    componente.enviar();
    expect(importar).not.toHaveBeenCalled();
    expect(componente.enviando()).toBe(false);
  });

  it('un lote válido se muestra como válido y se envía con la fuente elegida', () => {
    crear();
    completarValido();
    expect(q('validacion-ok')?.textContent).toContain('2 ítem(s) y 2 archivo(s)');
    componente.enviar();
    expect(importar).toHaveBeenCalledTimes(1);
    const [manifiesto, archivos] = importar.mock.calls[0] as [{ fuente: string; items: unknown[] }, File[]];
    expect(manifiesto.fuente).toBe('LAB-CENTRAL');
    expect(manifiesto.items).toHaveLength(2);
    expect(archivos.map((a) => a.name)).toEqual(['EXT-1.pdf', 'EXT-2.pdf']);
  });

  it('el clic en «Importar lote» envía por el formulario sin recargar la página', () => {
    crear();
    completarValido();
    const evento = new Event('submit', { cancelable: true });
    (q('btn-importar') as HTMLButtonElement).closest('form')?.dispatchEvent(evento);
    expect(evento.defaultPrevented).toBe(true);
    expect(importar).toHaveBeenCalledTimes(1);
  });

  it('al terminar guarda el manifiesto, va al informe y no deja el botón bloqueado', () => {
    crear();
    completarValido();
    componente.enviar();
    expect(navegar).toHaveBeenCalledWith(['/admin/resultados-laboratorio/sincronizaciones', 31]);
    expect(leerManifiesto(31)?.items).toHaveLength(2);
    expect(componente.enviando()).toBe(false);
  });

  it('muestra el progreso de subida, deshabilita el botón y evita el doble envío', () => {
    const subida = new Subject<EventoSubida>();
    importar.mockReturnValue(subida);
    crear();
    completarValido();
    componente.enviar();
    componente.enviar();
    expect(importar).toHaveBeenCalledTimes(1);

    subida.next({ tipo: 'progreso', porcentaje: 42, cargados: 420, total: 1000 });
    fixture.detectChanges();
    const barra = raiz().querySelector('[role="progressbar"]') as HTMLElement;
    expect(barra.getAttribute('aria-valuenow')).toBe('42');
    expect(q('progreso')?.textContent).toContain('42 %');
    expect(q('progreso')?.textContent).toContain('Subiendo archivos');
    const boton = q('btn-importar') as HTMLButtonElement;
    expect(boton.disabled).toBe(true);
    expect(boton.textContent).toContain('Importando');

    subida.next({ tipo: 'progreso', porcentaje: 100, cargados: 1000, total: 1000 });
    fixture.detectChanges();
    expect(q('progreso')?.textContent).toContain('Procesando en el servidor');

    subida.next({ tipo: 'respuesta', sincronizacion: syncDemo() });
    subida.complete();
    expect(componente.enviando()).toBe(false);
    expect(navegar).toHaveBeenCalledTimes(1);
  });

  it.each([
    ['LOTE_INVALIDO', 422, 'El lote no es válido', 'Detalle: El manifiesto repite un id_externo'],
    ['FUENTE_INACTIVA', 409, 'La fuente de laboratorio está inactiva', ''],
    ['FUENTE_NO_ENCONTRADA', 404, 'La fuente de laboratorio no existe en su clínica', ''],
  ])('muestra el error %s del servidor en español y rehabilita el envío', (codigo, status, esperado, detalle) => {
    importar.mockReturnValue(
      throwError(() => errorHttp(status, { detail: { codigo, mensaje: 'El manifiesto repite un id_externo dentro del lote.' } })),
    );
    crear();
    completarValido();
    componente.enviar();
    fixture.detectChanges();
    const texto = q('error-envio')?.textContent ?? '';
    expect(texto).toContain(esperado);
    if (detalle) expect(texto).toContain(detalle);
    expect(componente.enviando()).toBe(false);
    expect((q('btn-importar') as HTMLButtonElement).disabled).toBe(false);
    expect(navegar).not.toHaveBeenCalled();
  });

  it('acepta la lista de validación y el texto plano de 401/403', () => {
    importar.mockReturnValueOnce(throwError(() => errorHttp(422, { detail: [{ loc: ['body', 'manifiesto'], msg: 'Field required' }] })));
    crear();
    completarValido();
    componente.enviar();
    expect(componente.errorEnvio()).toContain('manifiesto: Field required');

    importar.mockReturnValueOnce(throwError(() => errorHttp(401, { detail: 'No autenticado' })));
    componente.enviar();
    expect(componente.errorEnvio()).toContain('sesión expiró');
  });

  it('el 400 de texto plano de Starlette (manifiesto > 1 MB) se explica', () => {
    importar.mockReturnValue(throwError(() => errorHttp(400, { detail: 'Part exceeded maximum size of 1024KB.' })));
    crear();
    completarValido();
    componente.enviar();
    expect(componente.errorEnvio()).toContain('manifiesto supera 1 MB');
  });

  it('avisa cuando el total supera ~50 MB y sugiere lotes más pequeños, sin bloquear', () => {
    crear();
    componente.alElegirFuente('2');
    const ids = Array.from({ length: 6 }, (_, i) => `E${i}`);
    componente.alEscribirManifiesto(JSON.stringify({ items: ids.map((id) => itemManifiestoDemo(id)) }));
    componente.archivos.set(ids.map((id) => archivoDemo(`${id}.pdf`, 10 * 1024 * 1024)));
    fixture.detectChanges();
    expect(q('aviso-tamano')?.textContent).toContain('dividir el lote');
    expect(componente.validacion().errores).toEqual([]);
  });

  it('permite quitar archivos de la selección', () => {
    crear();
    completarValido();
    raiz().querySelector<HTMLButtonElement>('[aria-label="Quitar el archivo EXT-2.pdf"]')?.click();
    fixture.detectChanges();
    expect(componente.archivos().map((a) => a.name)).toEqual(['EXT-1.pdf']);
    expect(q('resumen-archivos')?.textContent).toContain('1 archivo(s)');
  });

  it('carga el manifiesto desde un archivo .json', async () => {
    crear();
    const entrada = document.createElement('input');
    entrada.type = 'file';
    const archivo = new File([TEXTO], 'manifiesto.json', { type: 'application/json' });
    Object.defineProperty(entrada, 'files', { value: [archivo] });
    await componente.alElegirArchivoManifiesto(entrada);
    fixture.detectChanges();
    expect(componente.textoManifiesto()).toBe(TEXTO);
    expect(q('nombre-manifiesto')?.textContent).toContain('manifiesto.json');
  });
});
