import { Component, OnInit, inject, signal } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { Paciente } from '../../../../../../core/models/patient.models';
import {
  EstadoResultado,
  OrigenResultado,
  ResultadoLaboratorioQueryParams,
  ResultadoLaboratorioResumen,
} from '../../models/laboratory-result.models';
import { LaboratoryResultAccessService } from '../../services/laboratory-result-access.service';
import { LaboratoryResultsService } from '../../services/laboratory-results.service';
import { interpretarErrorResultado } from '../../utils/laboratory-result-errors';
import { LabPatientPicker } from '../lab-patient-picker/lab-patient-picker';
import { LabResultStatusBadge } from '../lab-result-status-badge/lab-result-status-badge';

/** Listado de resultados de la clínica con filtros (CU11, criterios 5 y 7). */
@Component({
  selector: 'app-laboratory-result-list',
  standalone: true,
  imports: [ReactiveFormsModule, RouterLink, LabPatientPicker, LabResultStatusBadge],
  templateUrl: './laboratory-result-list.html',
})
export class LaboratoryResultList implements OnInit {
  private readonly servicio = inject(LaboratoryResultsService);
  readonly acceso = inject(LaboratoryResultAccessService);

  readonly filtros = new FormGroup({
    estado: new FormControl<EstadoResultado | ''>('', { nonNullable: true }),
    codigo_examen: new FormControl('', { nonNullable: true }),
    laboratorio_origen: new FormControl('', { nonNullable: true }),
    origen: new FormControl<OrigenResultado | ''>('', { nonNullable: true }),
    fecha_desde: new FormControl('', { nonNullable: true }),
    fecha_hasta: new FormControl('', { nonNullable: true }),
  });
  private idPaciente: number | null = null;

  readonly items = signal<ResultadoLaboratorioResumen[]>([]);
  readonly total = signal(0);
  readonly pagina = signal(1);
  readonly totalPaginas = signal(1);
  readonly tamanoPagina = 10;
  readonly cargando = signal(false);
  readonly error = signal<string | null>(null);
  readonly rangoInvalido = signal(false);

  ngOnInit(): void {
    this.cargar(1);
  }

  alElegirPaciente(paciente: Paciente | null): void {
    this.idPaciente = paciente?.id_paciente ?? null;
    this.cargar(1);
  }

  filtrar(): void {
    this.cargar(1);
  }

  limpiar(): void {
    this.filtros.reset();
    this.cargar(1);
  }

  cargar(pagina: number): void {
    const f = this.filtros.getRawValue();
    this.rangoInvalido.set(!!f.fecha_desde && !!f.fecha_hasta && f.fecha_desde > f.fecha_hasta);
    if (this.rangoInvalido()) return;
    const parametros: ResultadoLaboratorioQueryParams = {
      page: pagina,
      page_size: this.tamanoPagina,
      id_paciente: this.idPaciente,
      codigo_examen: f.codigo_examen,
      laboratorio_origen: f.laboratorio_origen,
      origen: f.origen,
      fecha_desde: f.fecha_desde,
      fecha_hasta: f.fecha_hasta,
      // PENDIENTE_REVISION y ANULADO exigen lab_results:review; sin ese permiso nunca se envía `estado`.
      estado: this.acceso.puedeRevisar() ? f.estado : '',
    };
    this.cargando.set(true);
    this.error.set(null);
    this.servicio.listar(parametros).subscribe({
      next: (respuesta) => {
        this.items.set(respuesta.items);
        this.total.set(respuesta.total);
        this.pagina.set(respuesta.page);
        this.totalPaginas.set(respuesta.total_pages);
        this.cargando.set(false);
      },
      error: (error: unknown) => {
        this.items.set([]);
        this.total.set(0);
        this.cargando.set(false);
        this.error.set(interpretarErrorResultado(error).mensaje);
      },
    });
  }
}
