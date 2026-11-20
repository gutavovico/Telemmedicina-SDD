import { HttpErrorResponse } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PatientService } from '../../../../../../core/services/patient.service';
import { LaboratoryOrdersService } from '../../../../laboratory-orders/services/laboratory-orders.service';
import { LaboratoryResultAccessService } from '../../services/laboratory-result-access.service';
import { LaboratoryResultsService } from '../../services/laboratory-results.service';
import { accesoFalso, detalleDemo, listaDemo, pacienteDemo, resumenDemo } from '../../testing/lab-result.testing';
import { LaboratoryResultReview } from './laboratory-result-review';

const PENDIENTE = resumenDemo({
  id_resultado: 31, estado: 'PENDIENTE_REVISION', id_paciente: null, paciente_nombre: null, origen: 'SINCRONIZADO',
  motivo_pendiente: 'PACIENTE_NO_ENCONTRADO', fuente_codigo: 'LAB-CENTRAL', id_externo: 'EXT-9',
});

describe('LaboratoryResultReview', () => {
  let fixture: ComponentFixture<LaboratoryResultReview>;
  let componente: LaboratoryResultReview;
  let listar: ReturnType<typeof vi.fn>;
  let obtener: ReturnType<typeof vi.fn>;
  let resolver: ReturnType<typeof vi.fn>;

  const raiz = () => fixture.nativeElement as HTMLElement;

  function errorHttp(status: number, cuerpo: unknown): HttpErrorResponse {
    return new HttpErrorResponse({ status, error: cuerpo, statusText: 'x' });
  }

  function crear(descargar = true): void {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: LaboratoryResultsService, useValue: { listar, obtener, resolver, descargar: vi.fn() } },
        { provide: LaboratoryResultAccessService, useValue: accesoFalso({ leer: true, revisar: true, descargar }) },
        { provide: LaboratoryOrdersService, useValue: { getCatalogo: vi.fn(() => of([{ codigo: 'HEMOGRAMA', nombre: 'Hemograma completo' }])) } },
        { provide: PatientService, useValue: { getPatients: vi.fn() } },
      ],
    });
    fixture = TestBed.createComponent(LaboratoryResultReview);
    componente = fixture.componentInstance;
    fixture.detectChanges();
  }

  function abrir(): void {
    componente.revisar(31);
    fixture.detectChanges();
  }

  beforeEach(() => {
    listar = vi.fn(() => of(listaDemo([PENDIENTE])));
    obtener = vi.fn(() =>
      of(detalleDemo({
        ...PENDIENTE, observaciones: null,
        datos_correspondencia: { ci: '9999999', complemento: '', codigo_examen: 'HEMOGRAMA', id_orden: null },
      })),
    );
    resolver = vi.fn(() => of(detalleDemo({ estado: 'INCORPORADO' })));
  });

  it('pide solo los resultados PENDIENTE_REVISION y los lista con su motivo', () => {
    crear();
    expect(listar).toHaveBeenCalledWith({ estado: 'PENDIENTE_REVISION', page: 1, page_size: 10 });
    const fila = raiz().querySelector('[data-testid="fila-pendiente"]') as HTMLElement;
    expect(fila.textContent).toContain('LAB-CENTRAL');
    expect(fila.textContent).toContain('No se encontró un paciente');
    expect(fila.querySelector('[data-testid="estado-resultado"]')?.textContent).toContain('Pendiente de revisión');
  });

  it('muestra el estado vacío cuando no hay pendientes', () => {
    listar.mockReturnValue(of(listaDemo([])));
    crear();
    expect(raiz().querySelector('[data-testid="vacio"]')?.textContent).toContain('No hay resultados pendientes');
  });

  it('muestra el error de carga con opción de reintentar', () => {
    listar.mockReturnValueOnce(throwError(() => errorHttp(500, null)));
    crear();
    expect(raiz().querySelector('[data-testid="error-listado"]')?.getAttribute('role')).toBe('alert');
  });

  it('al revisar muestra los datos crudos recibidos de la fuente', () => {
    crear();
    abrir();
    expect(obtener).toHaveBeenCalledWith(31);
    expect(raiz().querySelector('[data-testid="datos-crudos"]')?.textContent).toContain('9999999');
    expect(raiz().querySelector('app-lab-result-file-viewer')).toBeTruthy();
    expect(componente.codigo.value).toBe('HEMOGRAMA'); // sugerido desde los datos recibidos
  });

  it('sin permiso de descarga no se ofrece el archivo en la revisión', () => {
    crear(false);
    abrir();
    expect(raiz().querySelector('app-lab-result-file-viewer')).toBeNull();
  });

  describe('asignar', () => {
    beforeEach(() => {
      crear();
      abrir();
    });

    it('exige paciente y estudio antes de enviar', () => {
      componente.codigo.setValue('');
      componente.resolver();
      fixture.detectChanges();
      expect(resolver).not.toHaveBeenCalled();
      expect(componente.mensajeCampo('id_paciente')).toContain('Seleccione el paciente');
      expect(componente.mensajeCampo('codigo_examen')).toContain('Seleccione el estudio');
      expect(raiz().querySelector('[data-testid="error-resolucion"]')?.textContent).toContain('Revise los campos');
    });

    it('envía ASIGNAR con los campos del contrato, informa y recarga la cola', () => {
      resolver.mockReturnValue(of(detalleDemo({ estado: 'INCORPORADO', nombre_examen: 'Hemograma completo', paciente_nombre: 'Carlos Mamani' })));
      componente.alElegirPaciente(pacienteDemo());
      componente.idOrden.setValue(7);
      listar.mockClear();
      componente.resolver();
      fixture.detectChanges();
      expect(resolver).toHaveBeenCalledWith(31, { accion: 'ASIGNAR', id_paciente: 10, codigo_examen: 'HEMOGRAMA', id_orden: 7 });
      expect(raiz().querySelector('[data-testid="exito-revision"]')?.textContent).toContain('Carlos Mamani');
      expect(raiz().querySelector('[data-testid="panel-resolucion"]')).toBeNull();
      expect(listar).toHaveBeenCalledTimes(1);
    });

    it('sin orden no incluye id_orden', () => {
      componente.alElegirPaciente(pacienteDemo());
      componente.resolver();
      expect(resolver).toHaveBeenCalledWith(31, { accion: 'ASIGNAR', id_paciente: 10, codigo_examen: 'HEMOGRAMA' });
    });

    it('muestra el error del servidor junto al campo (paciente de otra clínica: 404)', () => {
      resolver.mockReturnValue(throwError(() => errorHttp(404, { detail: { codigo: 'PACIENTE_NO_ENCONTRADO', mensaje: 'x' } })));
      componente.alElegirPaciente(pacienteDemo());
      componente.resolver();
      fixture.detectChanges();
      expect(raiz().querySelector('[data-testid="error-resolucion"]')?.textContent).toContain('no existe en su clínica');
      expect(componente.mensajeCampo('id_paciente')).toContain('no existe en su clínica');
      expect(raiz().querySelector('[data-testid="panel-resolucion"]')).toBeTruthy(); // permite corregir
    });

    it('un conflicto de estado (409) se explica y la cola no cambia', () => {
      resolver.mockReturnValue(throwError(() => errorHttp(409, { detail: { codigo: 'ESTADO_NO_PERMITIDO', mensaje: 'x' } })));
      componente.alElegirPaciente(pacienteDemo());
      componente.resolver();
      fixture.detectChanges();
      expect(raiz().querySelector('[data-testid="error-resolucion"]')?.textContent).toContain('no está en un estado');
    });
  });

  describe('descartar', () => {
    beforeEach(() => {
      crear();
      abrir();
      componente.elegirAccion('DESCARTAR');
      fixture.detectChanges();
    });

    it('exige un motivo de al menos 3 caracteres', () => {
      componente.motivo.setValue(' a ');
      componente.resolver();
      fixture.detectChanges();
      expect(resolver).not.toHaveBeenCalled();
      expect(componente.mensajeCampo('motivo')).toContain('motivo del descarte');
    });

    it('envía DESCARTAR con el motivo recortado', () => {
      resolver.mockReturnValue(of(detalleDemo({ estado: 'ANULADO' })));
      componente.motivo.setValue('  No corresponde a la clínica  ');
      componente.resolver();
      fixture.detectChanges();
      expect(resolver).toHaveBeenCalledWith(31, { accion: 'DESCARTAR', motivo: 'No corresponde a la clínica' });
      expect(raiz().querySelector('[data-testid="exito-revision"]')?.textContent).toContain('descartó');
    });
  });
});
