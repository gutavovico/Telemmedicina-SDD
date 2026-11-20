import { HttpErrorResponse } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter } from '@angular/router';
import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { LaboratoryResultAccessService } from '../../services/laboratory-result-access.service';
import { LaboratoryResultsService } from '../../services/laboratory-results.service';
import { PermisosFalsos, accesoFalso, detalleDemo } from '../../testing/lab-result.testing';
import { LaboratoryResultDetail } from './laboratory-result-detail';

describe('LaboratoryResultDetail', () => {
  let fixture: ComponentFixture<LaboratoryResultDetail>;
  let componente: LaboratoryResultDetail;
  let obtener: ReturnType<typeof vi.fn>;
  let anular: ReturnType<typeof vi.fn>;
  let descargar: ReturnType<typeof vi.fn>;

  function crear(permisos: PermisosFalsos, id = '15'): void {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: ActivatedRoute, useValue: { paramMap: of(convertToParamMap({ id })) } },
        { provide: LaboratoryResultsService, useValue: { obtener, anular, descargar } },
        { provide: LaboratoryResultAccessService, useValue: accesoFalso(permisos) },
      ],
    });
    fixture = TestBed.createComponent(LaboratoryResultDetail);
    componente = fixture.componentInstance;
    fixture.detectChanges();
  }

  const raiz = () => fixture.nativeElement as HTMLElement;

  beforeEach(() => {
    obtener = vi.fn(() => of(detalleDemo()));
    anular = vi.fn(() => of(detalleDemo({ estado: 'ANULADO', motivo_resolucion: 'Error de carga', resuelto_en: '2026-11-18T15:00:00Z' })));
    descargar = vi.fn();
  });

  it('muestra los datos del resultado, su estado y las observaciones', () => {
    crear({ leer: true, descargar: true });
    expect(obtener).toHaveBeenCalledWith(15);
    expect(raiz().querySelector('h1')?.textContent).toContain('Hemograma completo');
    expect(raiz().textContent).toContain('Laboratorio Central');
    expect(raiz().textContent).toContain('Sin orden asociada');
    expect(raiz().querySelector('[data-testid="estado-resultado"]')?.textContent).toContain('Incorporado');
    expect(raiz().querySelector('[data-testid="observaciones"]')?.textContent).toContain('Muestra en ayunas');
  });

  it('con permiso de descarga muestra el visor del archivo', () => {
    crear({ leer: true, descargar: true });
    expect(raiz().querySelector('app-lab-result-file-viewer')).toBeTruthy();
    expect(raiz().querySelector('[data-testid="sin-descarga"]')).toBeNull();
  });

  it('RECEPCION (lee, no descarga) no ve archivo ni observaciones ni hash', () => {
    obtener.mockReturnValue(of(detalleDemo({ observaciones: null, hash_archivo: null })));
    crear({ leer: true, crear: true });
    expect(raiz().querySelector('app-lab-result-file-viewer')).toBeNull();
    expect(raiz().querySelector('[data-testid="btn-descargar"]')).toBeNull();
    expect(raiz().querySelector('[data-testid="sin-descarga"]')?.textContent).toContain('no ver ni descargar el archivo');
    expect(raiz().querySelector('[data-testid="observaciones"]')).toBeNull();
    expect(raiz().textContent).not.toContain('SHA-256');
  });

  it('sin lab_results:review no se ofrece anular', () => {
    crear({ leer: true, descargar: true });
    expect(raiz().querySelector('[data-testid="btn-anular"]')).toBeNull();
  });

  it('un pendiente muestra el motivo y los datos de la fuente solo a quien puede revisar', () => {
    obtener.mockReturnValue(
      of(
        detalleDemo({
          estado: 'PENDIENTE_REVISION', id_paciente: null, paciente_nombre: null, motivo_pendiente: 'PACIENTE_NO_ENCONTRADO',
          datos_correspondencia: { ci: '9999999', complemento: '', codigo_examen: 'HEMOGRAMA' },
        }),
      ),
    );
    crear({ leer: true, revisar: true, descargar: true });
    expect(raiz().querySelector('[data-testid="motivo-pendiente"]')?.textContent).toContain('No se encontró un paciente');
    expect(raiz().querySelector('[data-testid="datos-correspondencia"]')?.textContent).toContain('9999999');
    expect(raiz().querySelector('app-lab-result-file-viewer')).toBeNull(); // el archivo solo se ofrece en INCORPORADO
    expect(raiz().querySelector('a[href="/admin/resultados-laboratorio/revision"]')).toBeTruthy();
  });

  describe('anulación (lab_results:review)', () => {
    beforeEach(() => crear({ leer: true, revisar: true, descargar: true }));

    it('exige un motivo antes de anular', () => {
      componente.abrirAnulacion();
      fixture.detectChanges();
      componente.confirmarAnulacion();
      fixture.detectChanges();
      expect(anular).not.toHaveBeenCalled();
      const alerta = raiz().querySelector('[data-testid="error-anulacion"]') as HTMLElement;
      expect(alerta.textContent).toContain('motivo');
      expect(alerta.getAttribute('role')).toBe('alert');
    });

    it('anula con el motivo indicado y refleja el nuevo estado', () => {
      (raiz().querySelector('[data-testid="btn-anular"]') as HTMLButtonElement).click();
      fixture.detectChanges();
      componente.motivo.setValue('  Error de carga  ');
      componente.confirmarAnulacion();
      fixture.detectChanges();
      expect(anular).toHaveBeenCalledWith(15, { motivo: 'Error de carga' });
      expect(raiz().querySelector('[data-testid="estado-resultado"]')?.textContent).toContain('Anulado');
      expect(raiz().querySelector('[data-testid="motivo-resolucion"]')?.textContent).toContain('Error de carga');
      expect(raiz().querySelector('[data-testid="btn-anular"]')).toBeNull();
      expect(raiz().querySelector('app-lab-result-file-viewer')).toBeNull();
    });

    it('muestra el error del servidor si no se puede anular', () => {
      anular.mockReturnValue(
        throwError(() => new HttpErrorResponse({ status: 409, error: { detail: { codigo: 'ESTADO_NO_PERMITIDO', mensaje: 'x' } } })),
      );
      componente.abrirAnulacion();
      componente.motivo.setValue('Otro motivo');
      componente.confirmarAnulacion();
      fixture.detectChanges();
      expect(raiz().querySelector('[data-testid="error-anulacion"]')?.textContent).toContain('no está en un estado');
      expect(componente.anulando()).toBe(false);
    });
  });

  it('un resultado que no existe o es de otra clínica se informa sin detalles', () => {
    obtener.mockReturnValue(
      throwError(() => new HttpErrorResponse({ status: 404, error: { detail: { codigo: 'RESULTADO_NO_ENCONTRADO', mensaje: 'x' } } })),
    );
    crear({ leer: true });
    expect(raiz().querySelector('[data-testid="error-detalle"]')?.textContent).toContain('no existe o no está disponible');
    expect(raiz().querySelector('h1')).toBeNull();
  });

  it('rechaza un identificador inválido sin llamar al servidor', () => {
    crear({ leer: true }, 'abc');
    expect(obtener).not.toHaveBeenCalled();
    expect(raiz().querySelector('[data-testid="error-detalle"]')?.textContent).toContain('no es válido');
  });
});
