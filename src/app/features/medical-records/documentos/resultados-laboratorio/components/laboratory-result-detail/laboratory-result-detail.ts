import { Component, DestroyRef, OnInit, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormControl, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { MotivoPendiente, ResultadoLaboratorio } from '../../models/laboratory-result.models';
import { LaboratoryResultAccessService } from '../../services/laboratory-result-access.service';
import { LaboratoryResultsService } from '../../services/laboratory-results.service';
import { interpretarErrorResultado } from '../../utils/laboratory-result-errors';
import { formatearTamano } from '../../utils/laboratory-result-file';
import { LabResultFileViewer } from '../lab-result-file-viewer/lab-result-file-viewer';
import { LabResultStatusBadge } from '../lab-result-status-badge/lab-result-status-badge';

export const MOTIVOS_PENDIENTE: Record<MotivoPendiente, string> = {
  PACIENTE_NO_ENCONTRADO: 'No se encontró un paciente de la clínica con la CI recibida.',
  PACIENTE_AMBIGUO: 'Más de un paciente de la clínica coincide con la CI recibida.',
  EXAMEN_NO_VALIDO: 'El estudio recibido no existe o está inactivo en el catálogo de la clínica.',
  ORDEN_NO_VALIDA: 'La orden indicada no es válida (no existe, no está firmada o no incluye el estudio).',
  ORDEN_PACIENTE_NO_COINCIDE: 'La orden indicada pertenece a otro paciente.',
};

/** Detalle de un resultado, con vista previa/descarga del archivo y anulación (CU11, criterios 7 y 9). */
@Component({
  selector: 'app-laboratory-result-detail',
  standalone: true,
  imports: [ReactiveFormsModule, RouterLink, LabResultStatusBadge, LabResultFileViewer],
  templateUrl: './laboratory-result-detail.html',
})
export class LaboratoryResultDetail implements OnInit {
  private readonly ruta = inject(ActivatedRoute);
  private readonly servicio = inject(LaboratoryResultsService);
  private readonly destroyRef = inject(DestroyRef);
  readonly acceso = inject(LaboratoryResultAccessService);

  readonly resultado = signal<ResultadoLaboratorio | null>(null);
  readonly cargando = signal(true);
  readonly error = signal<string | null>(null);

  readonly panelAnular = signal(false);
  readonly anulando = signal(false);
  readonly errorAnulacion = signal<string | null>(null);
  readonly motivo = new FormControl('', {
    nonNullable: true,
    validators: [Validators.required, Validators.minLength(3), Validators.maxLength(500)],
  });

  readonly formatearTamano = formatearTamano;
  readonly motivos = MOTIVOS_PENDIENTE;

  ngOnInit(): void {
    this.ruta.paramMap.pipe(takeUntilDestroyed(this.destroyRef)).subscribe((parametros) => {
      const id = Number(parametros.get('id'));
      if (!Number.isInteger(id) || id < 1) {
        this.cargando.set(false);
        this.error.set('El identificador del resultado no es válido.');
        return;
      }
      this.cargar(id);
    });
  }

  cargar(id: number): void {
    this.cargando.set(true);
    this.error.set(null);
    this.panelAnular.set(false);
    this.servicio.obtener(id).subscribe({
      next: (resultado) => {
        this.resultado.set(resultado);
        this.cargando.set(false);
      },
      error: (error: unknown) => {
        this.resultado.set(null);
        this.cargando.set(false);
        this.error.set(interpretarErrorResultado(error).mensaje);
      },
    });
  }

  abrirAnulacion(): void {
    this.motivo.reset('');
    this.errorAnulacion.set(null);
    this.panelAnular.set(true);
  }

  confirmarAnulacion(): void {
    const actual = this.resultado();
    if (!actual) return;
    if (this.motivo.invalid || !this.motivo.value.trim()) {
      this.motivo.markAsTouched();
      this.errorAnulacion.set('Indique el motivo de la anulación (entre 3 y 500 caracteres).');
      return;
    }
    this.anulando.set(true);
    this.errorAnulacion.set(null);
    this.servicio.anular(actual.id_resultado, { motivo: this.motivo.value.trim() }).subscribe({
      next: (anulado) => {
        this.anulando.set(false);
        this.panelAnular.set(false);
        this.resultado.set(anulado);
      },
      error: (error: unknown) => {
        this.anulando.set(false);
        this.errorAnulacion.set(interpretarErrorResultado(error).mensaje);
      },
    });
  }

  clavesCorrespondencia(resultado: ResultadoLaboratorio): Array<[string, string]> {
    const datos = resultado.datos_correspondencia;
    if (!datos) return [];
    return Object.entries(datos)
      .filter(([, valor]) => valor !== null && valor !== undefined && valor !== '')
      .map(([clave, valor]) => [clave, String(valor)] as [string, string]);
  }
}
