import { TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter } from '@angular/router';
import { of } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import { PatientService } from '../../../../../../core/services/patient.service';
import { LaboratoryOrdersService } from '../../../../laboratory-orders/services/laboratory-orders.service';
import { LaboratoryResultAccessService } from '../../services/laboratory-result-access.service';
import { LaboratoryResultsService } from '../../services/laboratory-results.service';
import { accesoFalso, listaDemo } from '../../testing/lab-result.testing';
import { LaboratoryResultReview } from './laboratory-result-review';

/** CU11 bloque B (tarea 7.5): la cola de revisión acepta `?id_fuente=` desde el informe de una sincronización. */
describe('LaboratoryResultReview · filtro por fuente', () => {
  function crear(query: Record<string, string>) {
    const listar = vi.fn(() => of(listaDemo([])));
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: ActivatedRoute, useValue: { snapshot: { queryParamMap: convertToParamMap(query) } } },
        { provide: LaboratoryResultsService, useValue: { listar, obtener: vi.fn(), resolver: vi.fn(), descargar: vi.fn() } },
        { provide: LaboratoryResultAccessService, useValue: accesoFalso({ leer: true, revisar: true }) },
        { provide: LaboratoryOrdersService, useValue: { getCatalogo: vi.fn(() => of([])) } },
        { provide: PatientService, useValue: { getPatients: vi.fn() } },
      ],
    });
    TestBed.createComponent(LaboratoryResultReview).detectChanges();
    return listar;
  }

  it('con id_fuente lo envía al listado de pendientes', () => {
    expect(crear({ id_fuente: '2' })).toHaveBeenCalledWith({ estado: 'PENDIENTE_REVISION', page: 1, page_size: 10, id_fuente: 2 });
  });

  it.each<Record<string, string>>([{}, { id_fuente: 'abc' }, { id_fuente: '0' }, { id_fuente: '-3' }])('sin un id_fuente válido (%j) no filtra', (query) => {
    expect(crear(query)).toHaveBeenCalledWith({ estado: 'PENDIENTE_REVISION', page: 1, page_size: 10 });
  });
});
