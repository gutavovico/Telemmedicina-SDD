import { HttpErrorResponse } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { Subject, of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { LaboratorySyncService } from '../../services/laboratory-sync.service';
import { fuenteDemo, listaFuentesDemo, listaSyncDemo, resumenSyncDemo } from '../../testing/lab-sync.testing';
import { LaboratorySyncList } from './laboratory-sync-list';

function errorHttp(status: number, cuerpo: unknown): HttpErrorResponse {
  return new HttpErrorResponse({ status, error: cuerpo, statusText: 'x' });
}

describe('LaboratorySyncList', () => {
  let fixture: ComponentFixture<LaboratorySyncList>;
  let componente: LaboratorySyncList;
  let listarSincronizaciones: ReturnType<typeof vi.fn>;
  let listarFuentes: ReturnType<typeof vi.fn>;

  const raiz = () => fixture.nativeElement as HTMLElement;
  const q = (testid: string) => raiz().querySelector(`[data-testid="${testid}"]`) as HTMLElement | null;

  function crear(): void {
    TestBed.configureTestingModule({
      providers: [provideRouter([]), { provide: LaboratorySyncService, useValue: { listarSincronizaciones, listarFuentes } }],
    });
    fixture = TestBed.createComponent(LaboratorySyncList);
    componente = fixture.componentInstance;
    fixture.detectChanges();
  }

  beforeEach(() => {
    listarFuentes = vi.fn(() => of(listaFuentesDemo([fuenteDemo()])));
    listarSincronizaciones = vi.fn(() =>
      of(listaSyncDemo([resumenSyncDemo(), resumenSyncDemo({ id_sincronizacion: 30, estado: 'FALLIDA', con_error: 4, incorporados: 0, pendientes: 0, duplicados: 0 })], { total: 12, total_pages: 2 })),
    );
  });

  it('lista el historial con estado, contadores y enlace al informe', () => {
    crear();
    expect(listarSincronizaciones).toHaveBeenCalledWith({ page: 1, page_size: 10, id_fuente: null, estado: '', fecha_desde: '', fecha_hasta: '' });
    const filas = raiz().querySelectorAll('[data-testid="fila-sincronizacion"]');
    expect(filas).toHaveLength(2);
    expect(filas[0].textContent).toContain('Completada con errores');
    expect(filas[1].textContent).toContain('Fallida');
    const enlaces = raiz().querySelectorAll<HTMLAnchorElement>('[data-testid="enlace-informe"]');
    expect(enlaces[0].getAttribute('href')).toBe('/admin/resultados-laboratorio/sincronizaciones/31');
    expect(enlaces[0].getAttribute('aria-label')).toBe('Ver el informe de la sincronización 31');
  });

  it('enlaza a Fuentes y a Importar lote', () => {
    crear();
    expect(q('enlace-fuentes')?.getAttribute('href')).toBe('/admin/resultados-laboratorio/fuentes');
    expect(q('enlace-importar')?.getAttribute('href')).toBe('/admin/resultados-laboratorio/sincronizaciones/importar');
  });

  it('pagina el historial', () => {
    crear();
    expect(raiz().querySelector('nav[aria-label="Paginación"]')?.textContent).toContain('12 sincronización(es) · página 1 de 2');
    componente.cargar(2);
    expect(listarSincronizaciones).toHaveBeenLastCalledWith(expect.objectContaining({ page: 2, page_size: 10 }));
  });

  it('filtra por fuente, estado y fechas, y vuelve a la página 1', () => {
    crear();
    componente.filtros.patchValue({ id_fuente: 2, estado: 'FALLIDA', fecha_desde: '2026-11-01', fecha_hasta: '2026-11-30' });
    componente.filtrar();
    expect(listarSincronizaciones).toHaveBeenLastCalledWith({
      page: 1, page_size: 10, id_fuente: 2, estado: 'FALLIDA', fecha_desde: '2026-11-01', fecha_hasta: '2026-11-30',
    });
    componente.limpiar();
    expect(listarSincronizaciones).toHaveBeenLastCalledWith({ page: 1, page_size: 10, id_fuente: null, estado: '', fecha_desde: '', fecha_hasta: '' });
  });

  it('las etiquetas de los filtros están asociadas a sus controles', () => {
    crear();
    for (const id of ['filtro-fuente', 'filtro-estado', 'filtro-desde', 'filtro-hasta']) {
      expect(raiz().querySelector(`label[for="${id}"]`), id).not.toBeNull();
      expect(raiz().querySelector(`#${id}`), id).not.toBeNull();
    }
  });

  it('muestra carga, vacío y error con reintento', () => {
    const pendiente = new Subject<ReturnType<typeof listaSyncDemo>>();
    listarSincronizaciones.mockReturnValue(pendiente);
    crear();
    expect(q('cargando')).not.toBeNull();
    pendiente.next(listaSyncDemo([]));
    pendiente.complete();
    fixture.detectChanges();
    expect(q('vacio')?.textContent).toContain('No hay sincronizaciones');

    listarSincronizaciones.mockReturnValue(throwError(() => errorHttp(403, { detail: "Permiso denegado. Se requiere el permiso 'lab_results:sync'." })));
    componente.cargar(1);
    fixture.detectChanges();
    expect(q('error-listado')?.textContent).toContain('lab_results:sync');
    expect(q('vacio')).toBeNull();
  });

  it('si fallan las fuentes del filtro, el historial sigue funcionando', () => {
    listarFuentes.mockReturnValue(throwError(() => errorHttp(500, null)));
    crear();
    expect(componente.fuentes()).toEqual([]);
    expect(raiz().querySelectorAll('[data-testid="fila-sincronizacion"]')).toHaveLength(2);
  });
});
