import { Component, ElementRef, OnInit, inject, signal, viewChild } from '@angular/core';
import { AbstractControl, FormControl, FormGroup, ReactiveFormsModule, ValidationErrors, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { Paciente } from '../../../../../../core/models/patient.models';
import { LaboratoryOrdersService } from '../../../../laboratory-orders/services/laboratory-orders.service';
import { ResultadoLaboratorio } from '../../models/laboratory-result.models';
import { LaboratoryResultsService } from '../../services/laboratory-results.service';
import { CatalogoEstudios } from '../../utils/catalogo-estudios';
import { interpretarErrorResultado } from '../../utils/laboratory-result-errors';
import {
  ACCEPT_ARCHIVO,
  esFechaFutura,
  formatearTamano,
  hoyIso,
  validarArchivoCliente,
} from '../../utils/laboratory-result-file';
import { LabPatientPicker } from '../lab-patient-picker/lab-patient-picker';

export interface FormularioResultado {
  paciente: FormControl<Paciente | null>;
  codigo_examen: FormControl<string>;
  fecha_realizacion: FormControl<string>;
  laboratorio_origen: FormControl<string>;
  id_orden: FormControl<number | null>;
  observaciones: FormControl<string>;
  archivo: FormControl<File | null>;
}

/** Validadores de la carga manual (ayuda de UX; el servidor valida de nuevo y manda). */
export function validadorFechaNoFutura(control: AbstractControl<string>): ValidationErrors | null {
  return control.value && esFechaFutura(control.value) ? { fechaFutura: true } : null;
}

export function validadorTextoNoVacio(control: AbstractControl<string>): ValidationErrors | null {
  return typeof control.value === 'string' && control.value.length > 0 && control.value.trim().length === 0
    ? { vacio: true }
    : null;
}

export function validadorArchivo(control: AbstractControl<File | null>): ValidationErrors | null {
  const problema = validarArchivoCliente(control.value);
  return problema ? { archivo: problema } : null;
}

/** Carga manual de un resultado de laboratorio (CU11, criterios 1, 2 y 3). */
@Component({
  selector: 'app-laboratory-result-form',
  standalone: true,
  imports: [ReactiveFormsModule, RouterLink, LabPatientPicker],
  templateUrl: './laboratory-result-form.html',
})
export class LaboratoryResultForm implements OnInit {
  private readonly resultados = inject(LaboratoryResultsService);
  private readonly ordenes = inject(LaboratoryOrdersService);

  readonly acceptArchivo = ACCEPT_ARCHIVO;
  readonly hoy = hoyIso();

  readonly formulario = new FormGroup<FormularioResultado>({
    paciente: new FormControl<Paciente | null>(null, { validators: [Validators.required] }),
    codigo_examen: new FormControl('', {
      nonNullable: true,
      validators: [Validators.required, Validators.maxLength(50), validadorTextoNoVacio],
    }),
    fecha_realizacion: new FormControl('', {
      nonNullable: true,
      validators: [Validators.required, validadorFechaNoFutura],
    }),
    laboratorio_origen: new FormControl('', {
      nonNullable: true,
      validators: [Validators.required, Validators.maxLength(200), validadorTextoNoVacio],
    }),
    id_orden: new FormControl<number | null>(null, { validators: [Validators.min(1)] }),
    observaciones: new FormControl('', { nonNullable: true, validators: [Validators.maxLength(2000)] }),
    archivo: new FormControl<File | null>(null, { validators: [Validators.required, validadorArchivo] }),
  });

  readonly catalogo = new CatalogoEstudios(this.ordenes);

  readonly intentoEnvio = signal(false);
  readonly enviando = signal(false);
  readonly errorGeneral = signal<string | null>(null);
  readonly erroresServidor = signal<Record<string, string>>({});
  readonly creado = signal<ResultadoLaboratorio | null>(null);

  private readonly selectorPaciente = viewChild(LabPatientPicker);
  private readonly campoArchivo = viewChild<ElementRef<HTMLInputElement>>('campoArchivo');

  readonly formatearTamano = formatearTamano;

  ngOnInit(): void {
    this.catalogo.cargar();
  }

  alElegirPaciente(paciente: Paciente | null): void {
    this.formulario.controls.paciente.setValue(paciente);
    this.formulario.controls.paciente.markAsTouched();
    this.limpiarErrorServidor('id_paciente');
  }

  alElegirArchivo(evento: Event): void {
    const entrada = evento.target as HTMLInputElement;
    const archivo = entrada.files && entrada.files.length > 0 ? entrada.files[0] : null;
    this.formulario.controls.archivo.setValue(archivo);
    this.formulario.controls.archivo.markAsTouched();
    this.limpiarErrorServidor('archivo');
  }

  limpiarErrorServidor(campo: string): void {
    const actuales = this.erroresServidor();
    if (campo in actuales) {
      const { [campo]: _quitado, ...resto } = actuales;
      this.erroresServidor.set(resto);
    }
    this.errorGeneral.set(null);
  }

  /** Mensaje del campo: error del servidor (siempre visible) o del cliente (tras tocar o intentar enviar). */
  mensajeCampo(campo: keyof FormularioResultado, claveServidor: string = campo): string | null {
    const delServidor = this.erroresServidor()[claveServidor];
    if (delServidor) return delServidor;
    const control = this.formulario.controls[campo];
    if (!control.invalid || !(control.touched || this.intentoEnvio())) return null;
    const e = control.errors ?? {};
    switch (campo) {
      case 'paciente':
        return 'Seleccione el paciente.';
      case 'codigo_examen':
        return e['maxlength'] ? 'El código del estudio admite hasta 50 caracteres.' : 'Seleccione el estudio.';
      case 'fecha_realizacion':
        return e['fechaFutura']
          ? 'La fecha de realización no puede ser posterior a hoy.'
          : 'Indique la fecha de realización.';
      case 'laboratorio_origen':
        return e['maxlength']
          ? 'El laboratorio de origen admite hasta 200 caracteres.'
          : 'Indique el laboratorio de origen.';
      case 'id_orden':
        return 'El número de orden debe ser un entero positivo.';
      case 'observaciones':
        return 'Las observaciones admiten hasta 2000 caracteres.';
      case 'archivo':
        return (e['archivo'] as string | undefined) ?? 'Seleccione el archivo del resultado.';
      default:
        return null;
    }
  }

  enviar(): void {
    this.intentoEnvio.set(true);
    this.errorGeneral.set(null);
    this.erroresServidor.set({});
    if (this.formulario.invalid) {
      this.formulario.markAllAsTouched();
      this.errorGeneral.set('Revise los campos marcados antes de continuar.');
      return;
    }
    const v = this.formulario.getRawValue();
    this.enviando.set(true);
    this.resultados
      .cargarManual({
        id_paciente: v.paciente!.id_paciente,
        codigo_examen: v.codigo_examen,
        fecha_realizacion: v.fecha_realizacion,
        laboratorio_origen: v.laboratorio_origen,
        id_orden: v.id_orden,
        observaciones: v.observaciones,
        archivo: v.archivo!,
      })
      .subscribe({
        next: (resultado) => {
          this.enviando.set(false);
          this.creado.set(resultado);
        },
        error: (error: unknown) => {
          const interpretado = interpretarErrorResultado(error);
          this.enviando.set(false);
          this.errorGeneral.set(interpretado.mensaje);
          this.erroresServidor.set(interpretado.campos);
        },
      });
  }

  nuevaCarga(): void {
    this.formulario.reset({
      paciente: null, codigo_examen: '', fecha_realizacion: '', laboratorio_origen: '',
      id_orden: null, observaciones: '', archivo: null,
    });
    const campo = this.campoArchivo();
    if (campo) campo.nativeElement.value = '';
    this.selectorPaciente()?.limpiar();
    this.intentoEnvio.set(false);
    this.errorGeneral.set(null);
    this.erroresServidor.set({});
    this.creado.set(null);
  }
}
