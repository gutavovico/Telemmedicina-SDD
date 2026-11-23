import { DatePipe } from '@angular/common';
import { Component, OnInit, inject, signal } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { EstadoSincronizacion, FuenteLaboratorio, SincronizacionResumen } from '../../models/laboratory-sync.models';
import { LaboratorySyncService } from '../../services/laboratory-sync.service';
import { ETIQUETAS_ESTADO_SINCRONIZACION, interpretarErrorSincronizacion } from '../../utils/laboratory-sync-errors';
import { LabSyncBadge } from '../lab-sync-badge/lab-sync-badge';

/** Historial paginado de sincronizaciones de la clínica (`GET /sincronizaciones-laboratorio`). Solo `lab_results:sync`. */
@Component({
  selector: 'app-laboratory-sync-list',
  standalone: true,
  imports: [ReactiveFormsModule, RouterLink, DatePipe, LabSyncBadge],
  templateUrl: './laboratory-sync-list.html',
})
export class LaboratorySyncList implements OnInit {
  private readonly servicio = inject(LaboratorySyncService);

  readonly estados = Object.entries(ETIQUETAS_ESTADO_SINCRONIZACION) as Array<[EstadoSincronizacion, string]>;
  readonly filtros = new FormGroup({
    id_fuente: new FormControl<number | null>(null),
    estado: new FormControl<EstadoSincronizacion | ''>('', { nonNullable: true }),
    fecha_desde: new FormControl('', { nonNullable: true }),
    fecha_hasta: new FormControl('', { nonNullable: true }),
  });

  readonly fuentes = signal<FuenteLaboratorio[]>([]);
  readonly items = signal<SincronizacionResumen[]>([]);
  readonly total = signal(0);
  readonly pagina = signal(1);
  readonly totalPaginas = signal(1);
  readonly cargando = signal(true);
  readonly error = signal<string | null>(null);

  ngOnInit(): void {
    // Las fuentes solo alimentan el filtro: si falla, el historial sigue funcionando sin él.
    this.servicio.listarFuentes({ page: 1, page_size: 100 }).subscribe({
      next: (respuesta) => this.fuentes.set(respuesta.items),
      error: () => this.fuentes.set([]),
    });
    this.cargar(1);
  }

  filtrar(): void {
    this.cargar(1);
  }

  limpiar(): void {
    this.filtros.reset({ id_fuente: null, estado: '', fecha_desde: '', fecha_hasta: '' });
    this.cargar(1);
  }

  cargar(pagina: number): void {
    const valores = this.filtros.getRawValue();
    this.cargando.set(true);
    this.error.set(null);
    this.servicio
      .listarSincronizaciones({
        page: pagina,
        page_size: 10,
        id_fuente: valores.id_fuente ? Number(valores.id_fuente) : null,
        estado: valores.estado,
        fecha_desde: valores.fecha_desde,
        fecha_hasta: valores.fecha_hasta,
      })
      .subscribe({
        next: (respuesta) => {
          this.items.set(respuesta.items);
          this.total.set(respuesta.total);
          this.pagina.set(respuesta.page);
          this.totalPaginas.set(respuesta.total_pages);
          this.cargando.set(false);
        },
        error: (error: unknown) => {
          this.items.set([]);
          this.cargando.set(false);
          this.error.set(interpretarErrorSincronizacion(error).mensaje);
        },
      });
  }
}
