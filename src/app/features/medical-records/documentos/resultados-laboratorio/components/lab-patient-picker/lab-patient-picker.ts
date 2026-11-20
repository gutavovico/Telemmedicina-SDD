import { Component, DestroyRef, inject, input, output, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { Subject, catchError, debounceTime, distinctUntilChanged, filter, of, switchMap, tap } from 'rxjs';
import { Paciente } from '../../../../../../core/models/patient.models';
import { PatientService } from '../../../../../../core/services/patient.service';

/**
 * Selector de paciente con búsqueda (reutiliza `PatientService.getPatients`, sin endpoints nuevos).
 * Patrón combobox accesible: `role="combobox"`, lista `role="listbox"`, navegación con flechas, Enter y Escape.
 */
@Component({
  selector: 'app-lab-patient-picker',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './lab-patient-picker.html',
})
export class LabPatientPicker {
  private readonly patientService = inject(PatientService);
  private readonly destroyRef = inject(DestroyRef);

  readonly inputId = input<string>('paciente');
  readonly etiqueta = input<string>('Paciente');
  readonly requerido = input<boolean>(false);
  readonly error = input<string | null>(null);
  readonly pacienteSeleccionado = output<Paciente | null>();

  readonly consulta = signal('');
  readonly resultados = signal<Paciente[]>([]);
  readonly cargando = signal(false);
  readonly errorBusqueda = signal<string | null>(null);
  readonly abierto = signal(false);
  readonly activo = signal(-1);
  readonly elegido = signal<Paciente | null>(null);

  private readonly busquedas = new Subject<string>();

  constructor() {
    this.busquedas
      .pipe(
        debounceTime(300),
        distinctUntilChanged(),
        tap((texto) => {
          if (texto.trim().length < 2) {
            this.resultados.set([]);
            this.cargando.set(false);
            this.abierto.set(false);
          }
        }),
        filter((texto) => texto.trim().length >= 2),
        tap(() => {
          this.cargando.set(true);
          this.errorBusqueda.set(null);
        }),
        switchMap((texto) =>
          this.patientService.getPatients(1, 8, texto).pipe(
            catchError(() => {
              this.errorBusqueda.set('No se pudo buscar pacientes. Intente nuevamente.');
              return of(null);
            }),
          ),
        ),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((respuesta) => {
        this.cargando.set(false);
        this.resultados.set(respuesta?.items ?? []);
        this.activo.set(-1);
        this.abierto.set(true);
      });
  }

  idOpcion(indice: number): string {
    return `${this.inputId()}-opcion-${indice}`;
  }

  alEscribir(texto: string): void {
    this.consulta.set(texto);
    if (this.elegido()) {
      this.elegido.set(null);
      this.pacienteSeleccionado.emit(null);
    }
    this.busquedas.next(texto);
  }

  alTeclear(evento: KeyboardEvent): void {
    const total = this.resultados().length;
    if (evento.key === 'ArrowDown') {
      evento.preventDefault();
      this.abierto.set(true);
      this.activo.set(total ? (this.activo() + 1) % total : -1);
    } else if (evento.key === 'ArrowUp') {
      evento.preventDefault();
      this.activo.set(total ? (this.activo() - 1 + total) % total : -1);
    } else if (evento.key === 'Enter' && this.abierto() && this.activo() >= 0) {
      evento.preventDefault();
      this.elegir(this.resultados()[this.activo()]);
    } else if (evento.key === 'Escape') {
      this.abierto.set(false);
    }
  }

  elegir(paciente: Paciente): void {
    this.elegido.set(paciente);
    this.consulta.set(`${paciente.nombres} ${paciente.apellidos} (CI ${paciente.ci})`);
    this.resultados.set([]);
    this.abierto.set(false);
    this.activo.set(-1);
    this.pacienteSeleccionado.emit(paciente);
  }

  quitar(): void {
    this.limpiar();
    this.pacienteSeleccionado.emit(null);
  }

  /** Vacía la búsqueda y la selección sin emitir (lo usa el formulario al reiniciarse). */
  limpiar(): void {
    this.elegido.set(null);
    this.consulta.set('');
    this.resultados.set([]);
    this.abierto.set(false);
    this.activo.set(-1);
    this.errorBusqueda.set(null);
  }
}
