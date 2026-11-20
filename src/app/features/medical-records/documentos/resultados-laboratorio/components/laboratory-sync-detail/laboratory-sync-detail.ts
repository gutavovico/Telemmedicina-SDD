import { DatePipe } from '@angular/common';
import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { ItemSincronizacion, Manifiesto, ProgresoSubida, Sincronizacion } from '../../models/laboratory-sync.models';
import { LaboratoryResultAccessService } from '../../services/laboratory-result-access.service';
import { LaboratorySyncService } from '../../services/laboratory-sync.service';
import { ACCEPT_ARCHIVO, formatearTamano } from '../../utils/laboratory-result-file';
import { guardarManifiesto, leerManifiesto } from '../../utils/laboratory-sync-cache';
import { interpretarErrorSincronizacion, mensajeDeItem } from '../../utils/laboratory-sync-errors';
import { armarManifiestoReintento, leerArchivoComoTexto, validarLote } from '../../utils/laboratory-sync-manifest';
import { LabSyncBadge } from '../lab-sync-badge/lab-sync-badge';
import { MOTIVOS_PENDIENTE } from '../laboratory-result-detail/laboratory-result-detail';

/** Informe de una sincronización (`GET /{id}`) y reintento de los ítems en ERROR (`POST /{id}/reintentos`). */
@Component({
  selector: 'app-laboratory-sync-detail',
  standalone: true,
  imports: [RouterLink, DatePipe, LabSyncBadge],
  templateUrl: './laboratory-sync-detail.html',
})
export class LaboratorySyncDetail implements OnInit {
  private readonly servicio = inject(LaboratorySyncService);
  private readonly ruta = inject(ActivatedRoute);
  readonly acceso = inject(LaboratoryResultAccessService);

  readonly acceptArchivos = ACCEPT_ARCHIVO;
  readonly formatearTamano = formatearTamano;

  readonly sincronizacion = signal<Sincronizacion | null>(null);
  readonly cargando = signal(true);
  readonly error = signal<string | null>(null);
  /** `true` cuando la sincronización no existe o es de otra clínica (404): no hay nada que reintentar. */
  readonly noEncontrada = signal(false);

  // --- Reintento ---
  readonly manifiestoOrigen = signal<Manifiesto | null>(null);
  readonly origenDesdeCache = signal(false);
  readonly errorManifiestoOrigen = signal<string | null>(null);
  readonly correcciones = signal<Record<string, File>>({});
  readonly reintentando = signal(false);
  readonly progreso = signal<ProgresoSubida | null>(null);
  readonly errorReintento = signal<string | null>(null);
  readonly exitoReintento = signal<string | null>(null);

  readonly items = computed<ItemSincronizacion[]>(() => this.sincronizacion()?.items ?? []);
  readonly itemsEnError = computed(() => this.items().filter((i) => i.resultado === 'ERROR'));
  readonly hayPendientes = computed(() => (this.sincronizacion()?.pendientes ?? 0) > 0);

  /** Manifiesto y archivos del reintento, validados con las mismas reglas que la importación. */
  readonly preparacion = computed(() => {
    const sync = this.sincronizacion();
    const origen = this.manifiestoOrigen();
    const seleccion = this.correcciones();
    const ids = Object.keys(seleccion);
    if (!sync || ids.length === 0) return { manifiesto: null as Manifiesto | null, archivos: [] as File[], errores: [] as string[], avisos: [] as string[] };
    if (!origen) {
      return { manifiesto: null, archivos: [], errores: ['Cargue el manifiesto original del lote para armar el reintento.'], avisos: [] };
    }
    const codigo = sync.fuente_codigo ?? origen.fuente;
    const armado = armarManifiestoReintento(origen, codigo, new Map(Object.entries(seleccion)));
    const errores = armado.faltantes.map((id) => `El ítem «${id}» no figura en el manifiesto cargado.`);
    const validacion = validarLote(JSON.stringify(armado.manifiesto), armado.archivos, codigo);
    errores.push(...validacion.errores);
    return {
      manifiesto: errores.length ? null : armado.manifiesto,
      archivos: armado.archivos,
      errores,
      avisos: validacion.avisos,
    };
  });

  ngOnInit(): void {
    this.cargar();
  }

  private idDeLaRuta(): number | null {
    const id = Number(this.ruta.snapshot.paramMap.get('id'));
    return Number.isInteger(id) && id > 0 ? id : null;
  }

  cargar(): void {
    const id = this.idDeLaRuta();
    if (id === null) {
      this.cargando.set(false);
      this.noEncontrada.set(true);
      this.error.set('El identificador de la sincronización no es válido.');
      return;
    }
    this.cargando.set(true);
    this.error.set(null);
    this.noEncontrada.set(false);
    this.servicio.obtenerSincronizacion(id).subscribe({
      next: (sync) => {
        this.sincronizacion.set(sync);
        this.cargando.set(false);
        if (!this.manifiestoOrigen()) {
          const guardado = leerManifiesto(sync.id_sincronizacion);
          this.manifiestoOrigen.set(guardado);
          this.origenDesdeCache.set(guardado !== null);
        }
      },
      error: (error: unknown) => {
        const interpretado = interpretarErrorSincronizacion(error);
        this.sincronizacion.set(null);
        this.cargando.set(false);
        this.noEncontrada.set(interpretado.codigo === 'SINCRONIZACION_NO_ENCONTRADA');
        this.error.set(interpretado.mensaje);
      },
    });
  }

  detalleDe(item: ItemSincronizacion): { codigo: string | null; mensaje: string | null } {
    return mensajeDeItem(item, MOTIVOS_PENDIENTE);
  }

  // --- Reintento ---
  async alCargarManifiestoOrigen(entrada: HTMLInputElement): Promise<void> {
    const archivo = entrada.files?.[0];
    if (!archivo) return;
    try {
      this.aplicarManifiestoOrigen(await leerArchivoComoTexto(archivo));
    } catch {
      this.errorManifiestoOrigen.set('No se pudo leer el archivo del manifiesto.');
    }
    entrada.value = '';
  }

  aplicarManifiestoOrigen(texto: string): void {
    this.errorManifiestoOrigen.set(null);
    if (!texto.trim()) {
      this.manifiestoOrigen.set(null);
      return;
    }
    try {
      const crudo: unknown = JSON.parse(texto);
      const items = typeof crudo === 'object' && crudo !== null ? (crudo as { items?: unknown }).items : undefined;
      if (!Array.isArray(items)) throw new Error('sin items');
      const fuente = (crudo as { fuente?: unknown }).fuente;
      this.manifiestoOrigen.set({
        fuente: typeof fuente === 'string' ? fuente : (this.sincronizacion()?.fuente_codigo ?? ''),
        items: items as Manifiesto['items'],
      });
      this.origenDesdeCache.set(false);
    } catch {
      this.manifiestoOrigen.set(null);
      this.errorManifiestoOrigen.set('El manifiesto no es un JSON válido con una lista «items».');
    }
  }

  alElegirCorreccion(idExterno: string, entrada: HTMLInputElement): void {
    const archivo = entrada.files?.[0];
    if (archivo) this.correcciones.update((actuales) => ({ ...actuales, [idExterno]: archivo }));
    entrada.value = '';
  }

  quitarCorreccion(idExterno: string): void {
    this.correcciones.update((actuales) => {
      const { [idExterno]: _quitado, ...resto } = actuales;
      return resto;
    });
  }

  reintentar(): void {
    const sync = this.sincronizacion();
    const preparado = this.preparacion();
    this.errorReintento.set(null);
    this.exitoReintento.set(null);
    if (!sync || this.reintentando() || !preparado.manifiesto) return; // evita el doble envío
    this.reintentando.set(true);
    this.progreso.set({ tipo: 'progreso', porcentaje: 0, cargados: 0, total: null });
    const enviados = preparado.manifiesto.items.length;
    this.servicio.reintentar(sync.id_sincronizacion, preparado.manifiesto, preparado.archivos).subscribe({
      next: (evento) => {
        if (evento.tipo === 'progreso') {
          this.progreso.set(evento);
          return;
        }
        this.reintentando.set(false);
        this.progreso.set(null);
        this.sincronizacion.set(evento.sincronizacion);
        this.correcciones.set({});
        const origen = this.manifiestoOrigen();
        if (origen) guardarManifiesto(sync.id_sincronizacion, origen);
        this.exitoReintento.set(
          `Reintento enviado: ${enviados} ítem(s). Estado de la sincronización: ${evento.sincronizacion.estado.replace(/_/g, ' ').toLowerCase()}.`,
        );
      },
      error: (error: unknown) => {
        this.reintentando.set(false);
        this.progreso.set(null);
        const interpretado = interpretarErrorSincronizacion(error);
        this.errorReintento.set(interpretado.mensaje);
        if (interpretado.codigo === 'SINCRONIZACION_NO_ENCONTRADA') this.noEncontrada.set(true);
        // El estado de los ítems cambió desde que se cargó el informe: se vuelve a leer para no insistir con datos viejos.
        if (interpretado.codigo === 'ITEM_NO_REINTENTABLE') {
          this.correcciones.set({});
          this.cargar();
        }
      },
    });
  }
}
