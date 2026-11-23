import { HttpErrorResponse } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { Subject, of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { LaboratorySyncService } from '../../services/laboratory-sync.service';
import { fuenteDemo, listaFuentesDemo } from '../../testing/lab-sync.testing';
import { LaboratorySources } from './laboratory-sources';

function errorHttp(status: number, cuerpo: unknown): HttpErrorResponse {
  return new HttpErrorResponse({ status, error: cuerpo, statusText: 'x' });
}

describe('LaboratorySources', () => {
  let fixture: ComponentFixture<LaboratorySources>;
  let componente: LaboratorySources;
  let listarFuentes: ReturnType<typeof vi.fn>;
  let crearFuente: ReturnType<typeof vi.fn>;
  let actualizarFuente: ReturnType<typeof vi.fn>;

  const raiz = () => fixture.nativeElement as HTMLElement;
  const q = (testid: string) => raiz().querySelector(`[data-testid="${testid}"]`) as HTMLElement | null;

  function crear(): void {
    TestBed.configureTestingModule({
      providers: [provideRouter([]), { provide: LaboratorySyncService, useValue: { listarFuentes, crearFuente, actualizarFuente } }],
    });
    fixture = TestBed.createComponent(LaboratorySources);
    componente = fixture.componentInstance;
    fixture.detectChanges();
  }

  beforeEach(() => {
    listarFuentes = vi.fn(() => of(listaFuentesDemo([fuenteDemo(), fuenteDemo({ id_fuente: 3, codigo: 'LAB-NORTE', nombre: 'Laboratorio Norte', activa: 'NO' })])));
    crearFuente = vi.fn(() => of(fuenteDemo({ codigo: 'LAB-NUEVA' })));
    actualizarFuente = vi.fn((id: number, cuerpo: { activa?: 'SI' | 'NO' }) => of(fuenteDemo({ id_fuente: id, codigo: id === 2 ? 'LAB-CENTRAL' : 'LAB-NORTE', activa: cuerpo.activa ?? 'SI' })));
  });

  it('lista las fuentes con su estado (texto, no solo color)', () => {
    crear();
    expect(listarFuentes).toHaveBeenCalledWith({ page: 1, page_size: 10, activa: '' });
    const filas = raiz().querySelectorAll('[data-testid="fila-fuente"]');
    expect(filas).toHaveLength(2);
    expect(filas[0].textContent).toContain('LAB-CENTRAL');
    expect(filas[0].textContent).toContain('Activa');
    expect(filas[1].textContent).toContain('Inactiva');
  });

  it('muestra el estado de carga, el vacío y el error con reintento', () => {
    const pendiente = new Subject<ReturnType<typeof listaFuentesDemo>>();
    listarFuentes = vi.fn(() => pendiente);
    crear();
    expect(q('cargando')?.textContent).toContain('Cargando fuentes');
    pendiente.next(listaFuentesDemo([]));
    pendiente.complete();
    fixture.detectChanges();
    expect(q('vacio')).not.toBeNull();

    listarFuentes.mockReturnValue(throwError(() => errorHttp(500, null)));
    componente.cargar(1);
    fixture.detectChanges();
    expect(q('error-listado')?.textContent).toContain('El servidor no pudo completar');
    expect(q('vacio')).toBeNull();
    listarFuentes.mockReturnValue(of(listaFuentesDemo([fuenteDemo()])));
    (q('error-listado')?.querySelector('button') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(raiz().querySelectorAll('[data-testid="fila-fuente"]')).toHaveLength(1);
  });

  it('el filtro de estado vuelve a consultar con activa', () => {
    crear();
    componente.filtroActiva.setValue('SI');
    expect(listarFuentes).toHaveBeenLastCalledWith({ page: 1, page_size: 10, activa: 'SI' });
  });

  it('crea una fuente enviando solo código y nombre, limpia el formulario y recarga', () => {
    crear();
    componente.formulario.setValue({ codigo: 'lab-nueva', nombre: 'Laboratorio Nuevo' });
    componente.crear();
    fixture.detectChanges();
    expect(crearFuente).toHaveBeenCalledWith({ codigo: 'lab-nueva', nombre: 'Laboratorio Nuevo' });
    expect(q('exito-fuente')?.textContent).toContain('LAB-NUEVA');
    expect(componente.formulario.getRawValue()).toEqual({ codigo: '', nombre: '' });
    expect(listarFuentes).toHaveBeenCalledTimes(2);
  });

  it('valida en el cliente antes de enviar (código con espacios, nombre corto)', () => {
    crear();
    componente.formulario.setValue({ codigo: 'LAB CENTRAL', nombre: 'ab' });
    componente.crear();
    fixture.detectChanges();
    expect(crearFuente).not.toHaveBeenCalled();
    expect(q('error-codigo')?.textContent).toContain('sin espacios');
    expect(q('error-nombre')?.textContent).toContain('al menos 3');
    expect(raiz().querySelector('#fuente-codigo')?.getAttribute('aria-invalid')).toBe('true');
  });

  it('muestra FUENTE_DUPLICADA (409) con un mensaje claro junto al código', () => {
    crearFuente.mockReturnValue(throwError(() => errorHttp(409, { detail: { codigo: 'FUENTE_DUPLICADA', mensaje: 'dup' } })));
    crear();
    componente.formulario.setValue({ codigo: 'LAB-CENTRAL', nombre: 'Otra vez' });
    componente.crear();
    fixture.detectChanges();
    expect(q('error-creacion')?.textContent).toContain('Ya existe una fuente con ese código');
    expect(q('error-codigo')?.textContent).toContain('Ya existe una fuente con ese código');
    expect(componente.creando()).toBe(false);
  });

  it('el botón se deshabilita durante el alta y no permite el doble envío', () => {
    const pendiente = new Subject<ReturnType<typeof fuenteDemo>>();
    crearFuente.mockReturnValue(pendiente);
    crear();
    componente.formulario.setValue({ codigo: 'LAB-NUEVA', nombre: 'Laboratorio Nuevo' });
    componente.crear();
    componente.crear();
    fixture.detectChanges();
    expect(crearFuente).toHaveBeenCalledTimes(1);
    expect((q('btn-crear-fuente') as HTMLButtonElement).disabled).toBe(true);
  });

  it('desactiva y reactiva una fuente con PATCH y actualiza la fila', () => {
    crear();
    const botones = raiz().querySelectorAll<HTMLButtonElement>('[data-testid="btn-alternar"]');
    expect(botones[0].getAttribute('aria-label')).toBe('Desactivar la fuente LAB-CENTRAL');
    botones[0].click();
    fixture.detectChanges();
    expect(actualizarFuente).toHaveBeenCalledWith(2, { activa: 'NO' });
    expect(raiz().querySelectorAll('[data-testid="fuente-estado"]')[0].textContent).toContain('Inactiva');
    expect(q('exito-fuente')?.textContent).toContain('desactivada');

    raiz().querySelectorAll<HTMLButtonElement>('[data-testid="btn-alternar"]')[1].click();
    expect(actualizarFuente).toHaveBeenLastCalledWith(3, { activa: 'SI' });
  });

  it('muestra el error si no se puede actualizar la fuente', () => {
    actualizarFuente.mockReturnValue(throwError(() => errorHttp(404, { detail: { codigo: 'FUENTE_NO_ENCONTRADA', mensaje: 'x' } })));
    crear();
    raiz().querySelector<HTMLButtonElement>('[data-testid="btn-alternar"]')?.click();
    fixture.detectChanges();
    expect(q('error-actualizacion')?.textContent).toContain('La fuente de laboratorio no existe en su clínica');
  });
});
