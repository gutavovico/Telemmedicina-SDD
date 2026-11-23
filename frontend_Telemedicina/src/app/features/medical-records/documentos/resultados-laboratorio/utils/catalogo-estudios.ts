import { signal } from '@angular/core';
import { LaboratoryOrdersService } from '../../../laboratory-orders/services/laboratory-orders.service';
import { interpretarErrorResultado } from './laboratory-result-errors';

export interface OpcionEstudio {
  codigo: string;
  nombre: string;
}

/**
 * Catálogo de estudios para los selectores de CU11. Reutiliza `GET /api/v1/ordenes-laboratorio/examenes`
 * (CU10, exige `lab_orders:read`); no existe un endpoint propio. Si el usuario no tiene ese permiso o la
 * consulta falla, `noDisponible` trae el aviso y el formulario ofrece escribir el código (el servidor lo
 * valida contra el catálogo de la clínica).
 */
export class CatalogoEstudios {
  readonly opciones = signal<OpcionEstudio[]>([]);
  readonly cargando = signal(true);
  readonly noDisponible = signal<string | null>(null);

  constructor(private readonly ordenes: LaboratoryOrdersService) {}

  cargar(): void {
    this.cargando.set(true);
    this.noDisponible.set(null);
    this.ordenes.getCatalogo().subscribe({
      next: (examenes) => {
        this.opciones.set(examenes.map((e) => ({ codigo: e.codigo, nombre: e.nombre })));
        this.cargando.set(false);
      },
      error: (error: unknown) => {
        const interpretado = interpretarErrorResultado(error);
        this.opciones.set([]);
        this.cargando.set(false);
        this.noDisponible.set(
          interpretado.status === 403
            ? 'No tiene permiso para consultar el catálogo de estudios (lab_orders:read). Escriba el código del estudio; el servidor lo validará.'
            : 'No se pudo cargar el catálogo de estudios. Escriba el código del estudio; el servidor lo validará.',
        );
      },
    });
  }
}
