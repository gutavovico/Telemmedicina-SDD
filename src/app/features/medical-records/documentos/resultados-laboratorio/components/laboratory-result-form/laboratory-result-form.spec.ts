import { HttpErrorResponse } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { Subject, of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PatientService } from '../../../../../../core/services/patient.service';
import { LaboratoryOrdersService } from '../../../../laboratory-orders/services/laboratory-orders.service';
import { LaboratoryResultsService } from '../../services/laboratory-results.service';
import { detalleDemo, pacienteDemo } from '../../testing/lab-result.testing';
import { LaboratoryResultForm } from './laboratory-result-form';

function archivo(nombre = 'hemograma.pdf', tamano = 2048): File {
  const f = new File(['%PDF-1.4'], nombre, { type: 'application/pdf' });
  Object.defineProperty(f, 'size', { value: tamano });
  return f;
}

function errorHttp(status: number, cuerpo: unknown): HttpErrorResponse {
  return new HttpErrorResponse({ status, error: cuerpo, statusText: 'x' });
}

describe('LaboratoryResultForm', () => {
  let fixture: ComponentFixture<LaboratoryResultForm>;
  let componente: LaboratoryResultForm;
  let cargarManual: ReturnType<typeof vi.fn>;
  let getCatalogo: ReturnType<typeof vi.fn>;

  async function crear(): Promise<void> {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: LaboratoryResultsService, useValue: { cargarManual } },
        { provide: LaboratoryOrdersService, useValue: { getCatalogo } },
        { provide: PatientService, useValue: { getPatients: vi.fn(() => of({ items: [], total: 0, page: 1, page_size: 8, total_pages: 1 })) } },
      ],
    });
    fixture = TestBed.createComponent(LaboratoryResultForm);
    componente = fixture.componentInstance;
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  const raiz = () => fixture.nativeElement as HTMLElement;

  function completar(cambios: { archivo?: File | null } = {}): void {
    componente.alElegirPaciente(pacienteDemo());
    componente.formulario.patchValue({
      codigo_examen: 'HEMOGRAMA',
      fecha_realizacion: '2026-11-10',
      laboratorio_origen: 'Laboratorio Central',
      archivo: cambios.archivo === undefined ? archivo() : cambios.archivo,
    });
  }

  beforeEach(async () => {
    cargarManual = vi.fn(() => of(detalleDemo()));
    getCatalogo = vi.fn(() =>
      of([
        { codigo: 'HEMOGRAMA', nombre: 'Hemograma completo' },
        { codigo: 'GLUCOSA', nombre: 'Glucosa' },
      ]),
    );
    await crear();
  });

  it('carga el catálogo de estudios del catálogo de CU10 en un selector', () => {
    expect(getCatalogo).toHaveBeenCalledTimes(1);
    const opciones = raiz().querySelectorAll('select#codigo_examen option');
    expect(opciones.length).toBe(3); // opción vacía + 2 estudios
    expect(opciones[1].textContent).toContain('Hemograma completo (HEMOGRAMA)');
  });

  it('todos los controles tienen una etiqueta asociada', () => {
    for (const id of ['codigo_examen', 'fecha_realizacion', 'laboratorio_origen', 'id_orden', 'observaciones', 'archivo']) {
      expect(raiz().querySelector(`label[for="${id}"]`), id).toBeTruthy();
      expect(raiz().querySelector(`#${id}`), id).toBeTruthy();
    }
    expect(raiz().querySelector('label[for="paciente"]')).toBeTruthy();
  });

  it('no envía un formulario incompleto y muestra los errores anunciables', () => {
    componente.enviar();
    fixture.detectChanges();
    expect(cargarManual).not.toHaveBeenCalled();
    expect(raiz().querySelector('[data-testid="error-general"]')?.textContent).toContain('Revise los campos');
    const alertas = Array.from(raiz().querySelectorAll('[role="alert"]')).map((e) => e.textContent ?? '');
    expect(alertas.join(' ')).toContain('Seleccione el paciente');
    expect(alertas.join(' ')).toContain('Seleccione el estudio');
    expect(alertas.join(' ')).toContain('Indique la fecha de realización');
    expect(alertas.join(' ')).toContain('Indique el laboratorio de origen');
    expect(alertas.join(' ')).toContain('Seleccione el archivo');
    expect(raiz().querySelector('#resumen-errores')?.getAttribute('aria-live')).toBe('assertive');
    expect(raiz().querySelector('#archivo')?.getAttribute('aria-invalid')).toBe('true');
  });

  it('la fecha de realización no puede ser futura', () => {
    completar();
    componente.formulario.controls.fecha_realizacion.setValue('2999-01-01');
    componente.enviar();
    fixture.detectChanges();
    expect(cargarManual).not.toHaveBeenCalled();
    expect(componente.mensajeCampo('fecha_realizacion')).toContain('posterior a hoy');
    expect(raiz().querySelector('#fecha_realizacion')?.getAttribute('max')).toBe(componente.hoy);
  });

  it.each([
    ['programa.exe', 1000, 'PDF, JPG o PNG'],
    ['vacio.pdf', 0, 'vacío'],
    ['grande.pdf', 10 * 1024 * 1024 + 1, '10 MB'],
  ])('valida el archivo en el cliente: %s', (nombre, tamano, texto) => {
    completar({ archivo: archivo(nombre, tamano) });
    componente.enviar();
    fixture.detectChanges();
    expect(cargarManual).not.toHaveBeenCalled();
    expect(componente.mensajeCampo('archivo')).toContain(texto);
  });

  it('el laboratorio de origen en blanco no es válido', () => {
    completar();
    componente.formulario.controls.laboratorio_origen.setValue('   ');
    expect(componente.formulario.controls.laboratorio_origen.errors?.['vacio']).toBe(true);
  });

  it('la orden debe ser un entero positivo', () => {
    completar();
    componente.formulario.controls.id_orden.setValue(0);
    componente.enviar();
    expect(componente.mensajeCampo('id_orden')).toContain('entero positivo');
    expect(cargarManual).not.toHaveBeenCalled();
  });

  it('envía los datos válidos solo con los campos del contrato y muestra el éxito', () => {
    completar();
    componente.formulario.patchValue({ id_orden: 7, observaciones: 'Muestra en ayunas' });
    componente.enviar();
    fixture.detectChanges();
    expect(cargarManual).toHaveBeenCalledTimes(1);
    const datos = cargarManual.mock.calls[0][0] as Record<string, unknown>;
    expect(Object.keys(datos).sort()).toEqual([
      'archivo', 'codigo_examen', 'fecha_realizacion', 'id_orden', 'id_paciente', 'laboratorio_origen', 'observaciones',
    ]);
    expect(datos['id_paciente']).toBe(10);
    expect(datos['codigo_examen']).toBe('HEMOGRAMA');
    expect(datos['id_orden']).toBe(7);
    expect(raiz().querySelector('[data-testid="carga-exitosa"]')?.textContent).toContain('Resultado incorporado');
    expect(raiz().querySelector('form')).toBeNull();
  });

  it('"Cargar otro resultado" reinicia el formulario', () => {
    completar();
    componente.enviar();
    fixture.detectChanges();
    componente.nuevaCarga();
    fixture.detectChanges();
    expect(raiz().querySelector('form')).toBeTruthy();
    expect(componente.formulario.controls.paciente.value).toBeNull();
    expect(componente.formulario.controls.archivo.value).toBeNull();
    expect(componente.creado()).toBeNull();
  });

  it('deshabilita el botón mientras guarda para evitar envíos dobles', () => {
    const respuesta = new Subject<ReturnType<typeof detalleDemo>>();
    cargarManual.mockReturnValue(respuesta);
    completar();
    componente.enviar();
    fixture.detectChanges();
    const boton = raiz().querySelector('button[type="submit"]') as HTMLButtonElement;
    expect(boton.disabled).toBe(true);
    expect(boton.textContent).toContain('Guardando');
    respuesta.next(detalleDemo());
    respuesta.complete();
  });

  it('muestra el error de duplicado del servidor (409) junto al archivo', () => {
    cargarManual.mockReturnValue(
      throwError(() => errorHttp(409, { detail: { codigo: 'RESULTADO_DUPLICADO', mensaje: 'Ya existe' } })),
    );
    completar();
    componente.enviar();
    fixture.detectChanges();
    expect(raiz().querySelector('[data-testid="error-general"]')?.textContent).toContain('mismo archivo');
    expect(raiz().querySelector('#archivo-error')?.textContent).toContain('mismo archivo');
    expect(componente.enviando()).toBe(false);
    expect(raiz().querySelector('form')).toBeTruthy(); // permite corregir y reintentar
  });

  it('muestra los errores de validación (lista de FastAPI) del servidor por campo', () => {
    cargarManual.mockReturnValue(
      throwError(() =>
        errorHttp(422, {
          detail: [{ type: 'value_error', loc: ['body', 'laboratorio_origen'], msg: 'El laboratorio de origen es obligatorio' }],
        }),
      ),
    );
    completar();
    componente.enviar();
    fixture.detectChanges();
    expect(raiz().querySelector('#laboratorio_origen-error')?.textContent).toContain('obligatorio');
  });

  it.each([
    ['ARCHIVO_TIPO_NO_PERMITIDO', 'archivo-error', 'PDF, JPG o PNG'],
    ['ARCHIVO_FIRMA_INVALIDA', 'archivo-error', 'no corresponde'],
    ['ARCHIVO_TAMANO_EXCEDIDO', 'archivo-error', '10 MB'],
    ['EXAMEN_NO_ENCONTRADO', 'codigo_examen-error', 'catálogo'],
    ['ORDEN_PACIENTE_NO_COINCIDE', 'id_orden-error', 'otro paciente'],
  ])('mapea el código %s a un mensaje claro en el campo correcto', (codigo, idError, texto) => {
    componente.formulario.controls.id_orden.setValue(7);
    cargarManual.mockReturnValue(throwError(() => errorHttp(422, { detail: { codigo, mensaje: 'x' } })));
    completar();
    componente.formulario.controls.id_orden.setValue(7);
    componente.enviar();
    fixture.detectChanges();
    expect(raiz().querySelector(`#${idError}`)?.textContent).toContain(texto);
  });

  it('el paciente de otra clínica (404) se informa junto al selector de paciente', () => {
    cargarManual.mockReturnValue(
      throwError(() => errorHttp(404, { detail: { codigo: 'PACIENTE_NO_ENCONTRADO', mensaje: 'x' } })),
    );
    completar();
    componente.enviar();
    fixture.detectChanges();
    expect(raiz().querySelector('#paciente-error')?.textContent).toContain('no existe en su clínica');
  });

  it('un error de permisos se muestra con su explicación', () => {
    cargarManual.mockReturnValue(
      throwError(() => errorHttp(403, { detail: "Permiso denegado. Se requiere el permiso 'lab_results:create'." })),
    );
    completar();
    componente.enviar();
    fixture.detectChanges();
    expect(raiz().querySelector('[data-testid="error-general"]')?.textContent).toContain('lab_results:create');
  });

  it('limpia el error del servidor de un campo al corregirlo', () => {
    cargarManual.mockReturnValue(
      throwError(() => errorHttp(422, { detail: { codigo: 'ARCHIVO_VACIO', mensaje: 'x' } })),
    );
    completar();
    componente.enviar();
    expect(componente.erroresServidor()['archivo']).toContain('vacío');
    componente.alElegirArchivo({ target: { files: [archivo('nuevo.pdf')] } } as unknown as Event);
    expect(componente.erroresServidor()['archivo']).toBeUndefined();
  });
});

describe('LaboratoryResultForm sin permiso para consultar el catálogo', () => {
  it('ofrece escribir el código del estudio y lo explica sin inventar un endpoint', async () => {
    const getCatalogo = vi.fn(() =>
      throwError(() => new HttpErrorResponse({ status: 403, error: { detail: "Permiso denegado. Se requiere el permiso 'lab_orders:read'." } })),
    );
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: LaboratoryResultsService, useValue: { cargarManual: vi.fn() } },
        { provide: LaboratoryOrdersService, useValue: { getCatalogo } },
        { provide: PatientService, useValue: { getPatients: vi.fn() } },
      ],
    });
    const fixture = TestBed.createComponent(LaboratoryResultForm);
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
    const raiz = fixture.nativeElement as HTMLElement;
    expect(raiz.querySelector('[data-testid="aviso-catalogo"]')?.textContent).toContain('lab_orders:read');
    expect(raiz.querySelector('input#codigo_examen')).toBeTruthy();
    expect(raiz.querySelector('select#codigo_examen')).toBeNull();
  });
});
