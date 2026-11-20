import { HttpErrorResponse } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { Subject, of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PatientService } from '../../../../../../core/services/patient.service';
import { LaboratoryResultAccessService } from '../../services/laboratory-result-access.service';
import { LaboratoryResultsService } from '../../services/laboratory-results.service';
import {
  PermisosFalsos,
  accesoFalso,
  listaDemo,
  pacienteDemo,
  resumenDemo,
} from '../../testing/lab-result.testing';
import { LaboratoryResultList } from './laboratory-result-list';

describe('LaboratoryResultList', () => {
  let fixture: ComponentFixture<LaboratoryResultList>;
  let componente: LaboratoryResultList;
  let listar: ReturnType<typeof vi.fn>;

  function crear(permisos: PermisosFalsos): void {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: LaboratoryResultsService, useValue: { listar } },
        { provide: LaboratoryResultAccessService, useValue: accesoFalso(permisos) },
        { provide: PatientService, useValue: { getPatients: vi.fn(() => of({ items: [], total: 0, page: 1, page_size: 8, total_pages: 1 })) } },
      ],
    });
    fixture = TestBed.createComponent(LaboratoryResultList);
    componente = fixture.componentInstance;
    fixture.detectChanges();
  }

  const raiz = () => fixture.nativeElement as HTMLElement;
  const textos = (selector: string) => Array.from(raiz().querySelectorAll(selector)).map((e) => e.textContent ?? '');

  beforeEach(() => {
    listar = vi.fn(() =>
      of(
        listaDemo(
          [
            resumenDemo(),
            resumenDemo({ id_resultado: 16, estado: 'PENDIENTE_REVISION', id_paciente: null, paciente_nombre: null, origen: 'SINCRONIZADO' }),
            resumenDemo({ id_resultado: 17, estado: 'ANULADO' }),
          ],
          { total: 3 },
        ),
      ),
    );
  });

  it('lista los resultados con una insignia visible por estado', () => {
    crear({ leer: true });
    expect(listar).toHaveBeenCalledTimes(1);
    expect(raiz().querySelectorAll('[data-testid="fila-resultado"]').length).toBe(3);
    expect(textos('[data-testid="estado-resultado"]')).toEqual([
      expect.stringContaining('Incorporado'),
      expect.stringContaining('Pendiente de revisión'),
      expect.stringContaining('Anulado'),
    ]);
    expect(raiz().textContent).toContain('Sin paciente asignado');
    expect(raiz().textContent).toContain('Sincronizado');
    expect(raiz().querySelector('caption')?.textContent).toContain('Resultados de laboratorio');
  });

  it('sin permisos de creación ni revisión no muestra esas acciones ni el filtro de estado', () => {
    crear({ leer: true });
    expect(raiz().querySelector('[data-testid="enlace-nuevo"]')).toBeNull();
    expect(raiz().querySelector('[data-testid="enlace-revision"]')).toBeNull();
    expect(raiz().querySelector('[data-testid="filtro-estado"]')).toBeNull();
  });

  it('con lab_results:create muestra "Cargar resultado"', () => {
    crear({ leer: true, crear: true });
    expect(raiz().querySelector('[data-testid="enlace-nuevo"]')?.getAttribute('href')).toBe('/admin/resultados-laboratorio/nuevo');
    expect(raiz().querySelector('[data-testid="enlace-revision"]')).toBeNull();
  });

  it('con lab_results:review muestra la revisión y el filtro de estado, y lo envía', () => {
    crear({ leer: true, revisar: true });
    expect(raiz().querySelector('[data-testid="enlace-revision"]')?.getAttribute('href')).toBe('/admin/resultados-laboratorio/revision');
    componente.filtros.controls.estado.setValue('PENDIENTE_REVISION');
    componente.filtrar();
    expect(listar).toHaveBeenLastCalledWith(expect.objectContaining({ estado: 'PENDIENTE_REVISION', page: 1 }));
  });

  it('sin lab_results:review nunca envía el estado aunque el formulario lo tenga', () => {
    crear({ leer: true });
    componente.filtros.controls.estado.setValue('ANULADO');
    componente.filtrar();
    expect(listar).toHaveBeenLastCalledWith(expect.objectContaining({ estado: '' }));
  });

  it('envía los filtros y el paciente elegido, y vuelve a la página 1', () => {
    crear({ leer: true });
    componente.alElegirPaciente(pacienteDemo());
    componente.filtros.patchValue({ codigo_examen: 'HEMOGRAMA', laboratorio_origen: 'Central', origen: 'MANUAL', fecha_desde: '2026-11-01', fecha_hasta: '2026-11-30' });
    componente.filtrar();
    expect(listar).toHaveBeenLastCalledWith({
      page: 1, page_size: 10, id_paciente: 10, codigo_examen: 'HEMOGRAMA', laboratorio_origen: 'Central',
      origen: 'MANUAL', fecha_desde: '2026-11-01', fecha_hasta: '2026-11-30', estado: '',
    });
  });

  it('no consulta si el rango de fechas es inválido y lo informa', () => {
    crear({ leer: true });
    listar.mockClear();
    componente.filtros.patchValue({ fecha_desde: '2026-12-01', fecha_hasta: '2026-11-01' });
    componente.filtrar();
    fixture.detectChanges();
    expect(listar).not.toHaveBeenCalled();
    expect(raiz().textContent).toContain('no puede ser posterior a la final');
  });

  it('muestra el estado de carga con aria-busy', () => {
    const pendiente = new Subject<ReturnType<typeof listaDemo>>();
    listar.mockReturnValue(pendiente);
    crear({ leer: true });
    expect(raiz().querySelector('[data-testid="cargando"]')?.getAttribute('role')).toBe('status');
    expect(raiz().querySelector('section[aria-busy="true"]')).toBeTruthy();
    pendiente.next(listaDemo([resumenDemo()]));
    pendiente.complete();
    fixture.detectChanges();
    expect(raiz().querySelector('[data-testid="cargando"]')).toBeNull();
  });

  it('muestra el estado vacío', () => {
    listar.mockReturnValue(of(listaDemo([])));
    crear({ leer: true });
    expect(raiz().querySelector('[data-testid="vacio"]')?.textContent).toContain('No hay resultados');
  });

  it('muestra el error del servidor y permite reintentar', () => {
    listar.mockReturnValueOnce(
      throwError(() => new HttpErrorResponse({ status: 403, error: { detail: "Permiso denegado. Se requiere el permiso 'lab_results:read'." } })),
    );
    crear({ leer: true });
    const alerta = raiz().querySelector('[data-testid="error-listado"]') as HTMLElement;
    expect(alerta.getAttribute('role')).toBe('alert');
    expect(alerta.textContent).toContain('lab_results:read');
    expect(raiz().querySelector('[data-testid="vacio"]')).toBeNull();
    (alerta.querySelector('button') as HTMLButtonElement).click();
    expect(listar).toHaveBeenCalledTimes(2);
  });

  it('pagina hacia delante y hacia atrás', () => {
    listar.mockReturnValue(of(listaDemo([resumenDemo()], { total: 25, total_pages: 3, page: 1 })));
    crear({ leer: true });
    const [anterior, siguiente] = Array.from(raiz().querySelectorAll('nav[aria-label="Paginación"] button')) as HTMLButtonElement[];
    expect(anterior.disabled).toBe(true);
    siguiente.click();
    expect(listar).toHaveBeenLastCalledWith(expect.objectContaining({ page: 2 }));
  });

  it('cada fila enlaza al detalle con un nombre accesible', () => {
    crear({ leer: true });
    const enlace = raiz().querySelector('[data-testid="fila-resultado"] a') as HTMLAnchorElement;
    expect(enlace.getAttribute('href')).toBe('/admin/resultados-laboratorio/15');
    expect(enlace.getAttribute('aria-label')).toContain('Hemograma completo');
  });
});
