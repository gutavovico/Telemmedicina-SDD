import { Injectable, inject } from '@angular/core';
import { PermissionsService } from '../../../../../core/services/permissions.service';
import { PERMISOS_RESULTADOS } from '../models/laboratory-result.models';

/**
 * Permisos granulares de CU11 sobre el mecanismo existente de la web (`PermissionsService`, alimentado por
 * el contexto del tenant). La descarga exige `lab_results:read` Y `documents:read:lab_results` (RECEPCION no
 * tiene el segundo). El backend es siempre la autoridad: esto solo decide qué mostrar.
 */
@Injectable({ providedIn: 'root' })
export class LaboratoryResultAccessService {
  private readonly permissions = inject(PermissionsService);

  puedeCrear(): boolean {
    return this.permissions.hasPermission(PERMISOS_RESULTADOS.create);
  }

  puedeLeer(): boolean {
    return this.permissions.hasPermission(PERMISOS_RESULTADOS.read);
  }

  puedeRevisar(): boolean {
    return this.permissions.hasPermission(PERMISOS_RESULTADOS.review);
  }

  /** Fuentes, importación por lote, informe y reintento (bloque B): solo `lab_results:sync` (ADMIN). */
  puedeSincronizar(): boolean {
    return this.permissions.hasPermission(PERMISOS_RESULTADOS.sync);
  }

  puedeDescargar(): boolean {
    return (
      this.permissions.hasPermission(PERMISOS_RESULTADOS.read) &&
      this.permissions.hasPermission(PERMISOS_RESULTADOS.descarga)
    );
  }
}
