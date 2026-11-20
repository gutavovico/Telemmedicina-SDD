import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';
import { EstadoResultado } from '../../models/laboratory-result.models';
import { LabResultStatusBadge } from './lab-result-status-badge';

describe('LabResultStatusBadge', () => {
  function pintar(estado: EstadoResultado): HTMLElement {
    const fixture = TestBed.createComponent(LabResultStatusBadge);
    fixture.componentRef.setInput('estado', estado);
    fixture.detectChanges();
    return fixture.nativeElement as HTMLElement;
  }

  it.each([
    ['INCORPORADO', 'Incorporado', 'emerald'],
    ['PENDIENTE_REVISION', 'Pendiente de revisión', 'amber'],
    ['ANULADO', 'Anulado', 'gray'],
  ] as Array<[EstadoResultado, string, string]>)('muestra una insignia visible para %s', (estado, etiqueta, color) => {
    const insignia = pintar(estado).querySelector('[data-testid="estado-resultado"]') as HTMLElement;
    expect(insignia.textContent).toContain(etiqueta);
    expect(insignia.className).toContain(color);
  });
});
