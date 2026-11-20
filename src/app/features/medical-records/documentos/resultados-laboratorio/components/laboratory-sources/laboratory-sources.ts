import { Component, DestroyRef, OnInit, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { ActivaFuente, FuenteLaboratorio } from '../../models/laboratory-sync.models';
import { LaboratorySyncService } from '../../services/laboratory-sync.service';
import { interpretarErrorSincronizacion } from '../../utils/laboratory-sync-errors';

/** Fuentes de laboratorio de la clínica: listado, alta y activar/desactivar (CU11, criterio 4). Solo `lab_results:sync`. */
@Component({
  selector: 'app-laboratory-sources',
  standalone: true,
  imports: [ReactiveFormsModule, RouterLink],
  templateUrl: './laboratory-sources.html',
})
export class LaboratorySources implements OnInit {
  private readonly servicio = inject(LaboratorySyncService);
  private readonly destroyRef = inject(DestroyRef);

  readonly items = signal<FuenteLaboratorio[]>([]);
  readonly total = signal(0);
  readonly pagina = signal(1);
  readonly totalPaginas = signal(1);
  readonly cargando = signal(true);
  readonly error = signal<string | null>(null);

  readonly creando = signal(false);
  readonly intento = signal(false);
  readonly errorCreacion = signal<string | null>(null);
  readonly erroresCampo = signal<Record<string, string>>({});
  readonly exito = signal<string | null>(null);
  readonly actualizando = signal<number | null>(null);
  readonly errorActualizacion = signal<string | null>(null);

  readonly filtroActiva = new FormControl<ActivaFuente | ''>('', { nonNullable: true });
  readonly formulario = new FormGroup({
    codigo: new FormControl('', {
      nonNullable: true,
      validators: [Validators.required, Validators.minLength(2), Validators.maxLength(50), Validators.pattern(/^[A-Za-z0-9_-]+$/)],
    }),
    nombre: new FormControl('', {
      nonNullable: true,
      validators: [Validators.required, Validators.minLength(3), Validators.maxLength(200)],
    }),
  });

  ngOnInit(): void {
    this.filtroActiva.valueChanges.pipe(takeUntilDestroyed(this.destroyRef)).subscribe(() => this.cargar(1));
    this.cargar(1);
  }

  cargar(pagina: number): void {
    this.cargando.set(true);
    this.error.set(null);
    this.servicio.listarFuentes({ page: pagina, page_size: 10, activa: this.filtroActiva.value }).subscribe({
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

  /** Mensaje de validación del cliente para un control (solo después de intentar enviar o de tocarlo). */
  errorDe(campo: 'codigo' | 'nombre'): string | null {
    const servidor = this.erroresCampo()[campo];
    if (servidor) return servidor;
    const control = this.formulario.controls[campo];
    if (!(this.intento() || control.touched) || control.valid) return null;
    if (control.hasError('required')) return campo === 'codigo' ? 'Ingrese el código de la fuente.' : 'Ingrese el nombre de la fuente.';
    if (control.hasError('minlength')) return campo === 'codigo' ? 'El código necesita al menos 2 caracteres.' : 'El nombre necesita al menos 3 caracteres.';
    if (control.hasError('maxlength')) return campo === 'codigo' ? 'El código admite hasta 50 caracteres.' : 'El nombre admite hasta 200 caracteres.';
    if (control.hasError('pattern')) return 'Use solo letras, dígitos, guion y guion bajo (sin espacios).';
    return 'Valor no válido.';
  }

  crear(): void {
    this.intento.set(true);
    this.errorCreacion.set(null);
    this.erroresCampo.set({});
    this.exito.set(null);
    if (this.formulario.invalid || this.creando()) {
      this.formulario.markAllAsTouched();
      return;
    }
    this.creando.set(true);
    const { codigo, nombre } = this.formulario.getRawValue();
    this.servicio.crearFuente({ codigo, nombre }).subscribe({
      next: (fuente) => {
        this.creando.set(false);
        this.intento.set(false);
        this.formulario.reset({ codigo: '', nombre: '' });
        this.exito.set(`Fuente ${fuente.codigo} creada y activa.`);
        this.cargar(1);
      },
      error: (error: unknown) => {
        this.creando.set(false);
        const interpretado = interpretarErrorSincronizacion(error);
        this.errorCreacion.set(interpretado.mensaje);
        this.erroresCampo.set(interpretado.campos);
      },
    });
  }

  alternar(fuente: FuenteLaboratorio): void {
    if (this.actualizando() !== null) return;
    this.actualizando.set(fuente.id_fuente);
    this.errorActualizacion.set(null);
    this.exito.set(null);
    const activa: ActivaFuente = fuente.activa === 'SI' ? 'NO' : 'SI';
    this.servicio.actualizarFuente(fuente.id_fuente, { activa }).subscribe({
      next: (actualizada) => {
        this.items.update((lista) => lista.map((f) => (f.id_fuente === actualizada.id_fuente ? actualizada : f)));
        this.actualizando.set(null);
        this.exito.set(`Fuente ${actualizada.codigo} ${actualizada.activa === 'SI' ? 'activada' : 'desactivada'}.`);
      },
      error: (error: unknown) => {
        this.actualizando.set(null);
        this.errorActualizacion.set(interpretarErrorSincronizacion(error).mensaje);
      },
    });
  }
}
