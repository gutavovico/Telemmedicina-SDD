import { HttpErrorResponse } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ArchivoDescargado } from '../../models/laboratory-result.models';
import { LaboratoryResultsService } from '../../services/laboratory-results.service';
import { LabResultFileViewer } from './lab-result-file-viewer';

function archivo(contentType: string, nombre: string): ArchivoDescargado {
  return { blob: new Blob(['contenido'], { type: contentType }), contentType, nombre };
}

describe('LabResultFileViewer', () => {
  let fixture: ComponentFixture<LabResultFileViewer>;
  let componente: LabResultFileViewer;
  let descargar: ReturnType<typeof vi.fn>;
  let crearUrl: ReturnType<typeof vi.fn>;
  let revocarUrl: ReturnType<typeof vi.fn>;
  const urlOriginalCrear = URL.createObjectURL;
  const urlOriginalRevocar = URL.revokeObjectURL;
  let contador = 0;

  beforeEach(() => {
    contador = 0;
    crearUrl = vi.fn(() => `blob:resultado-${++contador}`);
    revocarUrl = vi.fn();
    URL.createObjectURL = crearUrl as unknown as typeof URL.createObjectURL;
    URL.revokeObjectURL = revocarUrl as unknown as typeof URL.revokeObjectURL;
    descargar = vi.fn(() => of(archivo('image/png', 'imagen.png')));
    TestBed.configureTestingModule({
      providers: [{ provide: LaboratoryResultsService, useValue: { descargar } }],
    });
    fixture = TestBed.createComponent(LabResultFileViewer);
    componente = fixture.componentInstance;
    fixture.componentRef.setInput('idResultado', 15);
    fixture.detectChanges();
  });

  afterEach(() => {
    URL.createObjectURL = urlOriginalCrear;
    URL.revokeObjectURL = urlOriginalRevocar;
    vi.restoreAllMocks();
  });

  const raiz = () => fixture.nativeElement as HTMLElement;

  it('no descarga nada hasta que el usuario lo pide', () => {
    expect(descargar).not.toHaveBeenCalled();
    expect(raiz().querySelector('[data-testid="vista-previa"]')).toBeNull();
  });

  it('muestra una imagen con el tipo real devuelto por el servidor', () => {
    componente.alternarVistaPrevia();
    fixture.detectChanges();
    expect(descargar).toHaveBeenCalledWith(15);
    expect(crearUrl).toHaveBeenCalledTimes(1);
    const imagen = raiz().querySelector('[data-testid="vista-previa"] img') as HTMLImageElement;
    expect(imagen.getAttribute('src')).toBe('blob:resultado-1');
    expect(imagen.getAttribute('alt')).toContain('imagen.png');
    expect(raiz().querySelector('iframe')).toBeNull();
  });

  it('muestra un PDF en un marco con título accesible', () => {
    descargar.mockReturnValue(of(archivo('application/pdf', 'informe.pdf')));
    componente.alternarVistaPrevia();
    fixture.detectChanges();
    const marco = raiz().querySelector('[data-testid="vista-previa"] iframe') as HTMLIFrameElement;
    expect(marco).toBeTruthy();
    expect(marco.getAttribute('title')).toContain('informe.pdf');
  });

  it('un tipo sin vista previa ofrece solo la descarga', () => {
    descargar.mockReturnValue(of(archivo('application/zip', 'x.zip')));
    componente.alternarVistaPrevia();
    fixture.detectChanges();
    expect(raiz().querySelector('[data-testid="vista-previa"]')?.textContent).toContain('no admite vista previa');
  });

  it('alternar oculta la vista previa sin volver a descargar', () => {
    componente.alternarVistaPrevia();
    componente.alternarVistaPrevia();
    fixture.detectChanges();
    expect(raiz().querySelector('[data-testid="vista-previa"]')).toBeNull();
    componente.alternarVistaPrevia();
    expect(descargar).toHaveBeenCalledTimes(1);
  });

  it('descargar guarda el archivo con su nombre usando la misma URL de objeto', () => {
    const clic = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => undefined);
    let enlace: HTMLAnchorElement | null = null;
    clic.mockImplementation(function (this: HTMLAnchorElement) {
      enlace = this;
    });
    componente.alternarVistaPrevia();
    componente.descargar();
    expect(clic).toHaveBeenCalledTimes(1);
    expect(enlace!.download).toBe('imagen.png');
    expect(enlace!.href).toContain('blob:resultado-1');
    expect(descargar).toHaveBeenCalledTimes(1);
  });

  it('revoca la URL al destruir el componente', () => {
    componente.alternarVistaPrevia();
    fixture.destroy();
    expect(revocarUrl).toHaveBeenCalledWith('blob:resultado-1');
  });

  it('revoca la URL y reinicia al cambiar de resultado', () => {
    componente.alternarVistaPrevia();
    fixture.detectChanges();
    fixture.componentRef.setInput('idResultado', 16);
    fixture.detectChanges();
    expect(revocarUrl).toHaveBeenCalledWith('blob:resultado-1');
    expect(componente.archivo()).toBeNull();
    expect(componente.vistaPreviaVisible()).toBe(false);
    descargar.mockReturnValue(of(archivo('image/png', 'otra.png')));
    componente.alternarVistaPrevia();
    expect(descargar).toHaveBeenLastCalledWith(16);
  });

  it('al volver a cargar no deja URLs sin revocar', () => {
    componente.alternarVistaPrevia();
    fixture.componentRef.setInput('idResultado', 17);
    fixture.detectChanges();
    componente.alternarVistaPrevia();
    fixture.detectChanges();
    expect(crearUrl).toHaveBeenCalledTimes(2);
    expect(revocarUrl).toHaveBeenCalledTimes(1);
  });

  it('muestra el error del servidor con aria-live y permite reintentar', () => {
    descargar.mockReturnValueOnce(
      throwError(() => new HttpErrorResponse({ status: 404, error: { detail: { codigo: 'ARCHIVO_NO_ENCONTRADO', mensaje: 'x' } } })),
    );
    componente.alternarVistaPrevia();
    fixture.detectChanges();
    expect(raiz().querySelector('[data-testid="error-archivo"]')?.textContent).toContain('no se encuentra en el almacenamiento');
    expect(raiz().querySelector('[aria-live="polite"]')).toBeTruthy();
    expect(componente.vistaPreviaVisible()).toBe(false);
    componente.alternarVistaPrevia();
    expect(descargar).toHaveBeenCalledTimes(2);
  });

  it('deshabilita los botones mientras carga', () => {
    componente.cargando.set(true);
    fixture.detectChanges();
    const botones = raiz().querySelectorAll('button');
    botones.forEach((b) => expect((b as HTMLButtonElement).disabled).toBe(true));
    expect(raiz().textContent).toContain('Cargando archivo');
  });
});
