import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { PatientService } from '../../../../../../core/services/patient.service';
import { pacienteDemo } from '../../testing/lab-result.testing';
import { LabPatientPicker } from './lab-patient-picker';

describe('LabPatientPicker', () => {
  let fixture: ComponentFixture<LabPatientPicker>;
  let componente: LabPatientPicker;
  let getPatients: ReturnType<typeof vi.fn>;
  const carlos = pacienteDemo();
  const ana = pacienteDemo({ id_paciente: 11, nombres: 'Ana', apellidos: 'Ríos', ci: '7654321' });

  beforeEach(() => {
    vi.useFakeTimers();
    getPatients = vi.fn(() => of({ items: [carlos, ana], total: 2, page: 1, page_size: 8, total_pages: 1 }));
    TestBed.configureTestingModule({
      providers: [{ provide: PatientService, useValue: { getPatients } }],
    });
    fixture = TestBed.createComponent(LabPatientPicker);
    componente = fixture.componentInstance;
    fixture.detectChanges();
  });

  afterEach(() => vi.useRealTimers());

  function escribir(texto: string): void {
    componente.alEscribir(texto);
    vi.advanceTimersByTime(300);
    fixture.detectChanges();
  }

  it('no busca con menos de 2 caracteres', () => {
    escribir('c');
    expect(getPatients).not.toHaveBeenCalled();
    expect(componente.abierto()).toBe(false);
  });

  it('busca tras la pausa de escritura reutilizando PatientService y muestra las opciones', () => {
    escribir('car');
    expect(getPatients).toHaveBeenCalledTimes(1);
    expect(getPatients).toHaveBeenCalledWith(1, 8, 'car');
    const opciones = (fixture.nativeElement as HTMLElement).querySelectorAll('[role="option"]');
    expect(opciones.length).toBe(2);
    expect(opciones[0].textContent).toContain('Carlos Mamani');
  });

  it('expone la semántica de combobox accesible', () => {
    escribir('car');
    const entrada = (fixture.nativeElement as HTMLElement).querySelector('input') as HTMLInputElement;
    expect(entrada.getAttribute('role')).toBe('combobox');
    expect(entrada.getAttribute('aria-expanded')).toBe('true');
    expect((fixture.nativeElement as HTMLElement).querySelector('[role="listbox"]')).toBeTruthy();
    expect((fixture.nativeElement as HTMLElement).querySelector('label')?.getAttribute('for')).toBe('paciente');
  });

  it('elegir un paciente lo emite y muestra la confirmación', () => {
    const emitidos: Array<unknown> = [];
    componente.pacienteSeleccionado.subscribe((p) => emitidos.push(p));
    escribir('car');
    componente.elegir(carlos);
    fixture.detectChanges();
    expect(emitidos).toEqual([carlos]);
    expect((fixture.nativeElement as HTMLElement).querySelector('[data-testid="paciente-elegido"]')?.textContent).toContain(
      'Carlos Mamani',
    );
    expect(componente.abierto()).toBe(false);
  });

  it('la navegación con flechas y Enter elige la opción activa', () => {
    const emitidos: Array<unknown> = [];
    componente.pacienteSeleccionado.subscribe((p) => emitidos.push(p));
    escribir('car');
    componente.alTeclear(new KeyboardEvent('keydown', { key: 'ArrowDown' }));
    componente.alTeclear(new KeyboardEvent('keydown', { key: 'ArrowDown' }));
    expect(componente.activo()).toBe(1);
    componente.alTeclear(new KeyboardEvent('keydown', { key: 'Enter' }));
    expect(emitidos).toEqual([ana]);
  });

  it('Escape cierra la lista', () => {
    escribir('car');
    componente.alTeclear(new KeyboardEvent('keydown', { key: 'Escape' }));
    expect(componente.abierto()).toBe(false);
  });

  it('volver a escribir tras elegir deshace la selección', () => {
    const emitidos: Array<unknown> = [];
    componente.pacienteSeleccionado.subscribe((p) => emitidos.push(p));
    componente.elegir(carlos);
    componente.alEscribir('otro');
    expect(emitidos).toEqual([carlos, null]);
    expect(componente.elegido()).toBeNull();
  });

  it('quitar emite null y vacía el campo', () => {
    const emitidos: Array<unknown> = [];
    componente.pacienteSeleccionado.subscribe((p) => emitidos.push(p));
    componente.elegir(carlos);
    componente.quitar();
    expect(emitidos).toEqual([carlos, null]);
    expect(componente.consulta()).toBe('');
  });

  it('muestra un mensaje si la búsqueda falla', () => {
    getPatients.mockReturnValueOnce(throwError(() => new Error('falla')));
    escribir('car');
    expect(componente.errorBusqueda()).toContain('No se pudo buscar');
    expect((fixture.nativeElement as HTMLElement).querySelector('[role="alert"]')?.textContent).toContain('No se pudo buscar');
  });

  it('muestra "sin resultados" cuando no hay coincidencias', () => {
    getPatients.mockReturnValueOnce(of({ items: [], total: 0, page: 1, page_size: 8, total_pages: 1 }));
    escribir('zzz');
    expect((fixture.nativeElement as HTMLElement).textContent).toContain('No se encontraron pacientes');
  });

  it('presenta el error recibido del formulario con aria', () => {
    fixture.componentRef.setInput('error', 'Seleccione el paciente.');
    fixture.detectChanges();
    const entrada = (fixture.nativeElement as HTMLElement).querySelector('input') as HTMLInputElement;
    expect(entrada.getAttribute('aria-invalid')).toBe('true');
    expect((fixture.nativeElement as HTMLElement).querySelector('#paciente-error')?.textContent).toContain('Seleccione');
  });
});
