import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';
import { PermissionsService } from '../../../../../core/services/permissions.service';
import { LaboratoryResultAccessService } from './laboratory-result-access.service';

/** `puedeSincronizar` sigue la matriz del contrato: solo ADMIN tiene `lab_results:sync`. */
describe('LaboratoryResultAccessService · sincronización', () => {
  function acceso(permisos: string[]): LaboratoryResultAccessService {
    TestBed.configureTestingModule({
      providers: [{ provide: PermissionsService, useValue: { hasPermission: (p: string) => permisos.includes(p) } }],
    });
    return TestBed.inject(LaboratoryResultAccessService);
  }

  it.each([
    ['ADMIN', ['lab_results:create', 'lab_results:read', 'lab_results:review', 'lab_results:sync'], true],
    ['MEDICO', ['lab_results:create', 'lab_results:read', 'lab_results:review'], false],
    ['RECEPCION', ['lab_results:create', 'lab_results:read'], false],
    ['PACIENTE', ['lab_results:read'], false],
  ])('%s: puedeSincronizar = %s', (_rol, permisos, esperado) => {
    TestBed.resetTestingModule();
    expect(acceso(permisos).puedeSincronizar()).toBe(esperado);
  });
});
