import { Component, computed, input } from '@angular/core';
import { EstadoSincronizacion, ResultadoItem } from '../../models/laboratory-sync.models';
import { ETIQUETAS_ESTADO_SINCRONIZACION, ETIQUETAS_RESULTADO_ITEM } from '../../utils/laboratory-sync-errors';

interface Apariencia {
  etiqueta: string;
  icono: string;
  clases: string;
}

const CLASES = {
  verde: 'bg-emerald-50 text-emerald-800 border-emerald-200',
  ambar: 'bg-amber-50 text-amber-800 border-amber-200',
  rojo: 'bg-rose-50 text-rose-800 border-rose-200',
  azul: 'bg-sky-50 text-sky-800 border-sky-200',
} as const;

const LOTE: Record<EstadoSincronizacion, Apariencia> = {
  EN_PROCESO: { etiqueta: ETIQUETAS_ESTADO_SINCRONIZACION.EN_PROCESO, icono: 'sync', clases: CLASES.azul },
  COMPLETADA: { etiqueta: ETIQUETAS_ESTADO_SINCRONIZACION.COMPLETADA, icono: 'check_circle', clases: CLASES.verde },
  COMPLETADA_CON_ERRORES: {
    etiqueta: ETIQUETAS_ESTADO_SINCRONIZACION.COMPLETADA_CON_ERRORES,
    icono: 'warning',
    clases: CLASES.ambar,
  },
  FALLIDA: { etiqueta: ETIQUETAS_ESTADO_SINCRONIZACION.FALLIDA, icono: 'error', clases: CLASES.rojo },
};

const ITEM: Record<ResultadoItem, Apariencia> = {
  INCORPORADO: { etiqueta: ETIQUETAS_RESULTADO_ITEM.INCORPORADO, icono: 'check_circle', clases: CLASES.verde },
  PENDIENTE_REVISION: { etiqueta: ETIQUETAS_RESULTADO_ITEM.PENDIENTE_REVISION, icono: 'pending_actions', clases: CLASES.ambar },
  DUPLICADO: { etiqueta: ETIQUETAS_RESULTADO_ITEM.DUPLICADO, icono: 'content_copy', clases: CLASES.azul },
  ERROR: { etiqueta: ETIQUETAS_RESULTADO_ITEM.ERROR, icono: 'error', clases: CLASES.rojo },
};

/**
 * Insignia del estado de un lote (`EN_PROCESO`, `COMPLETADA`, `COMPLETADA_CON_ERRORES`, `FALLIDA`) o del resultado
 * de un ítem (`INCORPORADO`, `PENDIENTE_REVISION`, `DUPLICADO`, `ERROR`). Siempre con icono y texto (no solo color).
 */
@Component({
  selector: 'app-lab-sync-badge',
  standalone: true,
  template: `
    <span
      class="inline-flex items-center gap-1 rounded-full border px-2.5 py-0.5 text-xs font-semibold"
      [class]="apariencia().clases"
      data-testid="estado-sync"
    >
      <span class="material-symbols-outlined text-[14px]" aria-hidden="true">{{ apariencia().icono }}</span>
      {{ apariencia().etiqueta }}
    </span>
  `,
})
export class LabSyncBadge {
  readonly tipo = input.required<'lote' | 'item'>();
  readonly valor = input.required<EstadoSincronizacion | ResultadoItem>();

  readonly apariencia = computed<Apariencia>(() => {
    const valor = this.valor();
    const tabla = (this.tipo() === 'lote' ? LOTE : ITEM) as Record<string, Apariencia>;
    return tabla[valor] ?? { etiqueta: valor, icono: 'help', clases: 'bg-gray-100 text-gray-700 border-gray-300' };
  });
}
