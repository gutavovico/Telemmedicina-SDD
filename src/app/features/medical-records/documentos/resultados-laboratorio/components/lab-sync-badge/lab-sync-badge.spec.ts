import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';
import { EstadoSincronizacion, ResultadoItem } from '../../models/laboratory-sync.models';
import { LabSyncBadge } from './lab-sync-badge';

@Component({
  standalone: true,
  imports: [LabSyncBadge],
  template: `<app-lab-sync-badge [tipo]="tipo()" [valor]="valor()" />`,
})
class Anfitrion {
  readonly tipo = signal<'lote' | 'item'>('lote');
  readonly valor = signal<EstadoSincronizacion | ResultadoItem>('COMPLETADA');
}

describe('LabSyncBadge', () => {
  function texto(tipo: 'lote' | 'item', valor: EstadoSincronizacion | ResultadoItem): string {
    const fixture = TestBed.createComponent(Anfitrion);
    fixture.componentInstance.tipo.set(tipo);
    fixture.componentInstance.valor.set(valor);
    fixture.detectChanges();
    return (fixture.nativeElement as HTMLElement).querySelector('[data-testid="estado-sync"]')?.textContent?.replace(/\s+/g, ' ').trim() ?? '';
  }

  it.each([
    ['EN_PROCESO', 'sync En proceso'],
    ['COMPLETADA', 'check_circle Completada'],
    ['COMPLETADA_CON_ERRORES', 'warning Completada con errores'],
    ['FALLIDA', 'error Fallida'],
  ] as const)('estado de lote %s con icono y texto', (valor, esperado) => {
    expect(texto('lote', valor)).toBe(esperado);
  });

  it.each([
    ['INCORPORADO', 'check_circle Incorporado'],
    ['PENDIENTE_REVISION', 'pending_actions Pendiente de revisión'],
    ['DUPLICADO', 'content_copy Duplicado'],
    ['ERROR', 'error Error'],
  ] as const)('resultado de ítem %s con icono y texto', (valor, esperado) => {
    expect(texto('item', valor)).toBe(esperado);
  });

  it('un valor desconocido se muestra tal cual en lugar de romper', () => {
    expect(texto('item', 'NUEVO' as ResultadoItem)).toContain('NUEVO');
  });
});
