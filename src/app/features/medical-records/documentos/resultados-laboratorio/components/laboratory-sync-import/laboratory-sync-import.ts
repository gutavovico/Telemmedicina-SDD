import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { FuenteLaboratorio, ProgresoSubida } from '../../models/laboratory-sync.models';
import { formatearTamano } from '../../utils/laboratory-result-file';
import { guardarManifiesto } from '../../utils/laboratory-sync-cache';
import { interpretarErrorSincronizacion } from '../../utils/laboratory-sync-errors';
import { leerArchivoComoTexto, validarLote } from '../../utils/laboratory-sync-manifest';
import { LaboratorySyncService } from '../../services/laboratory-sync.service';
import { ACCEPT_ARCHIVO } from '../../utils/laboratory-result-file';

/** Ejemplo mostrado en la ayuda del formulario (campos del contrato 2.7). */
export const EJEMPLO_MANIFIESTO = `{
  "items": [
    {
      "id_externo": "LAB-2026-000123",
      "ci": "1234567",
      "complemento": "",
      "codigo_examen": "HEMOGRAMA",
      "laboratorio_origen": "Laboratorio Central S.R.L.",
      "fecha_realizacion": "2026-11-10",
      "nombre_archivo": "hemograma.pdf",
      "id_orden": null,
      "observaciones": null
    }
  ]
}`;

/**
 * Importación por lote (CU11, criterios 4, 6 y 8): fuente activa + manifiesto JSON + archivos, enviados como
 * `multipart/form-data`. Valida en el cliente como ayuda de UX; el servidor es la autoridad y su error se muestra siempre.
 */
@Component({
  selector: 'app-laboratory-sync-import',
  standalone: true,
  imports: [RouterLink],
  templateUrl: './laboratory-sync-import.html',
})
export class LaboratorySyncImport implements OnInit {
  private readonly servicio = inject(LaboratorySyncService);
  private readonly router = inject(Router);

  readonly acceptArchivos = ACCEPT_ARCHIVO;
  readonly ejemplo = EJEMPLO_MANIFIESTO;
  readonly formatearTamano = formatearTamano;

  readonly fuentes = signal<FuenteLaboratorio[]>([]);
  readonly cargandoFuentes = signal(true);
  readonly errorFuentes = signal<string | null>(null);
  readonly idFuente = signal<number | null>(null);
  readonly textoManifiesto = signal('');
  readonly nombreManifiesto = signal<string | null>(null);
  readonly archivos = signal<File[]>([]);
  readonly intento = signal(false);

  readonly enviando = signal(false);
  readonly progreso = signal<ProgresoSubida | null>(null);
  readonly errorEnvio = signal<string | null>(null);

  readonly fuenteCodigo = computed(() => this.fuentes().find((f) => f.id_fuente === this.idFuente())?.codigo ?? null);
  readonly validacion = computed(() => validarLote(this.textoManifiesto(), this.archivos(), this.fuenteCodigo()));
  /** Los errores de validación se muestran en cuanto el usuario empieza a completar el formulario. */
  readonly mostrarValidacion = computed(
    () => this.intento() || this.textoManifiesto().trim().length > 0 || this.archivos().length > 0,
  );

  ngOnInit(): void {
    this.servicio.listarFuentes({ activa: 'SI', page: 1, page_size: 100 }).subscribe({
      next: (respuesta) => {
        this.fuentes.set(respuesta.items);
        this.cargandoFuentes.set(false);
        if (respuesta.items.length === 1) this.idFuente.set(respuesta.items[0].id_fuente);
      },
      error: (error: unknown) => {
        this.cargandoFuentes.set(false);
        this.errorFuentes.set(interpretarErrorSincronizacion(error).mensaje);
      },
    });
  }

  alElegirFuente(valor: string): void {
    this.idFuente.set(valor ? Number(valor) : null);
  }

  alEscribirManifiesto(texto: string): void {
    this.textoManifiesto.set(texto);
    this.nombreManifiesto.set(null);
  }

  async alElegirArchivoManifiesto(entrada: HTMLInputElement): Promise<void> {
    const archivo = entrada.files?.[0];
    if (!archivo) return;
    try {
      this.textoManifiesto.set(await leerArchivoComoTexto(archivo));
      this.nombreManifiesto.set(archivo.name);
    } catch {
      this.textoManifiesto.set('');
      this.nombreManifiesto.set(null);
      this.errorEnvio.set('No se pudo leer el archivo del manifiesto. Pruebe pegando su contenido.');
    }
    entrada.value = '';
  }

  alElegirArchivos(entrada: HTMLInputElement): void {
    const nuevos = Array.from(entrada.files ?? []);
    if (nuevos.length > 0) this.archivos.update((actuales) => [...actuales, ...nuevos]);
    entrada.value = ''; // permite volver a elegir el mismo archivo
  }

  quitarArchivo(indice: number): void {
    this.archivos.update((actuales) => actuales.filter((_, i) => i !== indice));
  }

  limpiarArchivos(): void {
    this.archivos.set([]);
  }

  enviar(): void {
    this.intento.set(true);
    this.errorEnvio.set(null);
    if (this.enviando()) return; // evita el doble envío
    const manifiesto = this.validacion().manifiesto;
    if (!manifiesto) return;

    this.enviando.set(true);
    this.progreso.set({ tipo: 'progreso', porcentaje: 0, cargados: 0, total: null });
    this.servicio.importar(manifiesto, this.archivos()).subscribe({
      next: (evento) => {
        if (evento.tipo === 'progreso') {
          this.progreso.set(evento);
          return;
        }
        const sincronizacion = evento.sincronizacion;
        guardarManifiesto(sincronizacion.id_sincronizacion, manifiesto);
        this.enviando.set(false);
        this.progreso.set(null);
        void this.router.navigate(['/admin/resultados-laboratorio/sincronizaciones', sincronizacion.id_sincronizacion]);
      },
      error: (error: unknown) => {
        this.enviando.set(false);
        this.progreso.set(null);
        this.errorEnvio.set(interpretarErrorSincronizacion(error).mensaje);
      },
    });
  }
}
