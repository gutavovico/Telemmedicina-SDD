import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { of } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import { PatientService } from '../../../../../../core/services/patient.service';
import { LaboratoryResultAccessService } from '../../services/laboratory-result-access.service';
import { LaboratoryResultsService } from '../../services/laboratory-results.service';
import { PermisosFalsos, accesoFalso, listaDemo } from '../../testing/lab-result.testing';
import { LaboratoryResultList } from './laboratory-result-list';

/** CU11 bloque B: el listado de resultados ofrece el acceso a las sincronizaciones solo con `lab_results:sync`. */
describe('LaboratoryResultList · enlace a sincronizaciones', () => {
  function enlace(permisos: PermisosFalsos): HTMLAnchorElement | null {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: LaboratoryResultsService, useValue: { listar: vi.fn(() => of(listaDemo([]))) } },
        { provide: LaboratoryResultAccessService, useValue: accesoFalso(permisos) },
        { provide: PatientService, useValue: { getPatients: vi.fn(() => of({ items: [], total: 0, page: 1, page_size: 8, total_pages: 1 })) } },
      ],
    });
    const fixture = TestBed.createComponent(LaboratoryResultList);
    fixture.detectChanges();
    return (fixture.nativeElement as HTMLElement).querySelector('[data-testid="enlace-sincronizaciones"]');
  }

  it('lo muestra con lab_results:sync y apunta al historial', () => {
    const a = enlace({ leer: true, sincronizar: true });
    expect(a?.getAttribute('href')).toBe('/admin/resultados-laboratorio/sincronizaciones');
  });

  it('no lo muestra sin lab_results:sync', () => {
    expect(enlace({ leer: true, crear: true, revisar: true })).toBeNull();
  });
});
