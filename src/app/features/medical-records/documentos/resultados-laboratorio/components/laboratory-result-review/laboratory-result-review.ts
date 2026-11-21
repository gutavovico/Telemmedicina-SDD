import { Component, OnInit, ViewChild, inject, signal } from '@angular/core';
import { FormControl, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { Paciente } from '../../../../../../core/models/patient.models';
import { LaboratoryOrdersService } from '../../../../laboratory-orders/services/laboratory-orders.service';
import {
  ResolverPendienteRequest,
  ResultadoLaboratorio,
  ResultadoLaboratorioResumen,
} from '../../models/laboratory-result.models';
import { LaboratoryResultAccessService } from '../../services/laboratory-result-access.service';
import { LaboratoryResultsService } from '../../services/laboratory-results.service';
import { CatalogoEstudios } from '../../utils/catalogo-estudios';
import { interpretarErrorResultado } from '../../utils/laboratory-result-errors';
import { LabPatientPicker } from '../lab-patient-picker/lab-patient-picker';
import { LabResultFileViewer } from '../lab-result-file-viewer/lab-result-file-viewer';
import { LabResultStatusBadge } from '../lab-result-status-badge/lab-result-status-badge';
import { MOTIVOS_PENDIENTE } from '../laboratory-result-detail/laboratory-result-detail';

type AccionRevision = 'ASIGNAR' | 'DESCARTAR';

/** Cola de revisión de resultados pendientes: asignar a un paciente y estudio, o descartar (CU11, criterio 5). */
@Component({
  selector: 'app-laboratory-result-review',
  standalone: true,
  imports: [ReactiveFormsModule, RouterLink, LabPatientPicker, LabResultFileViewer, LabResultStatusBadge],
  templateUrl: './laboratory-result-review.html',
})
export class LaboratoryResultReview implements OnInit {
  private readonly servicio = inject(LaboratoryResultsService);
  private readonly ordenes = inject(LaboratoryOrdersService);
  private readonly ruta = inject(ActivatedRoute);
  readonly acceso = inject(LaboratoryResultAccessService);

  readonly catalogo = new CatalogoEstudios(this.ordenes);
  readonly motivos = MOTIVOS_PENDIENTE;

  readonly items = signal<ResultadoLaboratorioResumen[]>([]);
  readonly total = signal(0);
  readonly pagina = signal(1);
  readonly totalPaginas = signal(1);
  readonly cargando = signal(true);
  readonly error = signal<string | null>(null);

  readonly seleccionado = signal<ResultadoLaboratorio | null>(null);
  readonly cargandoSeleccion = signal(false);
  readonly accion = signal<AccionRevision>('ASIGNAR');
  readonly paciente = signal<Paciente | null>(null);
  readonly intento = signal(false);
  readonly enviando = signal(false);
  readonly errorResolucion = signal<string | null>(null);
  readonly erroresCampo = signal<Record<string, string>>({});
  readonly exito = signal<string | null>(null);

  readonly codigo = new FormControl('', { nonNullable: true, validators: [Validators.maxLength(50)] });
  readonly idOrden = new FormControl<number | null>(null, { validators: [Validators.min(1)] });
  readonly motivo = new FormControl('', { nonNullable: true, validators: [Validators.maxLength(500)] });

  @ViewChild(LabPatientPicker) private selector?: LabPatientPicker;

  ngOnInit(): void {
    this.catalogo.cargar();
    this.cargar(1);
  }

  cargar(pagina: number): void {
    this.cargando.set(true);
    this.error.set(null);
    // Opcional: `?id_fuente=` (enlace desde el informe de una sincronización) limita la cola a esa fuente.
    const idFuente = Number(this.ruta.snapshot.queryParamMap.get('id_fuente'));
    const filtroFuente = Number.isInteger(idFuente) && idFuente > 0 ? { id_fuente: idFuente } : {};
    this.servicio.listar({ estado: 'PENDIENTE_REVISION', page: pagina, page_size: 10, ...filtroFuente }).subscribe({
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
        this.error.set(interpretarErrorResultado(error).mensaje);
      },
    });
  }

  revisar(idResultado: number): void {
    this.cargandoSeleccion.set(true);
    this.exito.set(null);
    this.servicio.obtener(idResultado).subscribe({
      next: (detalle) => {
        this.cargandoSeleccion.set(false);
        this.abrir(detalle);
      },
      error: (error: unknown) => {
        this.cargandoSeleccion.set(false);
        this.error.set(interpretarErrorResultado(error).mensaje);
      },
    });
  }

  private abrir(detalle: ResultadoLaboratorio): void {
    this.seleccionado.set(detalle);
    this.accion.set('ASIGNAR');
    this.paciente.set(null);
    this.intento.set(false);
    this.errorResolucion.set(null);
    this.erroresCampo.set({});
    this.motivo.reset('');
    this.idOrden.reset(null);
    this.codigo.reset(String(detalle.datos_correspondencia?.codigo_examen ?? detalle.codigo_examen ?? ''));
    this.selector?.limpiar();
  }

  cerrar(): void {
    this.seleccionado.set(null);
  }

  elegirAccion(accion: AccionRevision): void {
    this.accion.set(accion);
    this.errorResolucion.set(null);
    this.erroresCampo.set({});
  }

  alElegirPaciente(paciente: Paciente | null): void {
    this.paciente.set(paciente);
    this.quitarError('id_paciente');
  }

  quitarError(campo: string): void {
    const { [campo]: _quitado, ...resto } = this.erroresCampo();
    this.erroresCampo.set(resto);
    this.errorResolucion.set(null);
  }

  /** Mensaje del campo: error del servidor o validación local una vez intentado el envío. */
  mensajeCampo(campo: 'id_paciente' | 'codigo_examen' | 'id_orden' | 'motivo'): string | null {
    const servidor = this.erroresCampo()[campo];
    if (servidor) return servidor;
    if (!this.intento()) return null;
    if (campo === 'id_paciente' && !this.paciente()) return 'Seleccione el paciente.';
    if (campo === 'codigo_examen' && this.accion() === 'ASIGNAR') {
      if (!this.codigo.value.trim()) return 'Seleccione el estudio.';
      if (this.codigo.invalid) return 'El código del estudio admite hasta 50 caracteres.';
    }
    if (campo === 'id_orden' && this.idOrden.invalid) return 'El número de orden debe ser un entero positivo.';
    if (campo === 'motivo' && this.accion() === 'DESCARTAR') {
      const texto = this.motivo.value.trim();
      if (texto.length < 3) return 'Indique el motivo del descarte (entre 3 y 500 caracteres).';
      if (this.motivo.invalid) return 'El motivo admite hasta 500 caracteres.';
    }
    return null;
  }

  resolver(): void {
    const actual = this.seleccionado();
    if (!actual) return;
    this.intento.set(true);
    this.errorResolucion.set(null);
    this.erroresCampo.set({});
    let solicitud: ResolverPendienteRequest;
    if (this.accion() === 'ASIGNAR') {
      const paciente = this.paciente();
      if (!paciente || !this.codigo.value.trim() || this.codigo.invalid || this.idOrden.invalid) {
        this.errorResolucion.set('Revise los campos marcados antes de continuar.');
        return;
      }
      solicitud = {
        accion: 'ASIGNAR',
        id_paciente: paciente.id_paciente,
        codigo_examen: this.codigo.value.trim(),
        ...(this.idOrden.value != null ? { id_orden: this.idOrden.value } : {}),
      };
    } else {
      const texto = this.motivo.value.trim();
      if (texto.length < 3 || this.motivo.invalid) {
        this.errorResolucion.set('Revise los campos marcados antes de continuar.');
        return;
      }
      solicitud = { accion: 'DESCARTAR', motivo: texto };
    }
    this.enviando.set(true);
    this.servicio.resolver(actual.id_resultado, solicitud).subscribe({
      next: (resuelto) => {
        this.enviando.set(false);
        this.seleccionado.set(null);
        this.exito.set(
          resuelto.estado === 'INCORPORADO'
            ? `El resultado de ${resuelto.nombre_examen || resuelto.codigo_examen} se incorporó al expediente de ${resuelto.paciente_nombre}.`
            : 'El resultado pendiente se descartó (anulado).',
        );
        this.cargar(this.pagina());
      },
      error: (error: unknown) => {
        const interpretado = interpretarErrorResultado(error);
        this.enviando.set(false);
        this.errorResolucion.set(interpretado.mensaje);
        this.erroresCampo.set(interpretado.campos);
      },
    });
  }
}
