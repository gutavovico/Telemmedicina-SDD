import { Component, computed, input } from '@angular/core';
import { EstadoResultado } from '../../models/laboratory-result.models';

interface Apariencia {
  etiqueta: string;
  icono: string;
  clases: string;
}

const APARIENCIAS: Record<EstadoResultado, Apariencia> = {
  INCORPORADO: {
    etiqueta: 'Incorporado',
    icono: 'check_circle',
    clases: 'bg-emerald-50 text-emerald-800 border-emerald-200',
  },
  PENDIENTE_REVISION: {
    etiqueta: 'Pendiente de revisión',
    icono: 'pending_actions',
    clases: 'bg-amber-50 text-amber-800 border-amber-200',
  },
  ANULADO: {
    etiqueta: 'Anulado',
    icono: 'block',
    clases: 'bg-gray-100 text-gray-700 border-gray-300',
  },
};

/** Insignia visible del estado de un resultado (INCORPORADO, PENDIENTE_REVISION, ANULADO). */
@Component({
  selector: 'app-lab-result-status-badge',
  standalone: true,
  template: `
    <span
      class="inline-flex items-center gap-1 rounded-full border px-2.5 py-0.5 text-xs font-semibold"
      [class]="apariencia().clases"
      data-testid="estado-resultado"
    >
      <span class="material-symbols-outlined text-[14px]" aria-hidden="true">{{ apariencia().icono }}</span>
      {{ apariencia().etiqueta }}
    </span>
  `,
})
export class LabResultStatusBadge {
  readonly estado = input.required<EstadoResultado>();
  readonly apariencia = computed(() => APARIENCIAS[this.estado()]);
}
