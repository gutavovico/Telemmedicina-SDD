import { Component, inject, signal } from '@angular/core';
import { NgTemplateOutlet } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { HttpErrorResponse } from '@angular/common/http';
import { TenantService } from '../../../core/services/tenant.service';
import {
  Configuracion,
  Sede,
  Servicio,
  Intervalo,
} from './models/entity-configuration.model';
import { ConfigurationService } from './services/configuration.service';

type Seccion = 'carga' | 'tema' | 'identidad' | 'direccion' | 'sedes' | 'servicios' | 'horarios';
type Resultado = { seccion: Seccion; tipo: 'exito' | 'error'; texto: string };

@Component({
  standalone: true,
  imports: [ReactiveFormsModule, NgTemplateOutlet],
  templateUrl: './entity-configuration.html',
  styleUrl: './entity-configuration.css',
})
export class EntityConfiguration {
  private readonly api = inject(ConfigurationService);
  private readonly tenant = inject(TenantService);
  private readonly fb = inject(FormBuilder).nonNullable;
  readonly datos = signal<Configuracion | null>(null);
  readonly ocupado = signal(false);
  readonly resultado = signal<Resultado | null>(null);
  readonly dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  readonly colores = this.fb.group({ principal: '#003667', secundario: '#006b5f' });
  readonly direccion = this.fb.control('', Validators.required);
  readonly sede = this.fb.group({
    nombre: ['', Validators.required],
    ubicacion: ['', Validators.required],
  });
  readonly servicio = this.fb.group({
    nombre: ['', Validators.required],
    modalidad: 'PRESENCIAL',
    duracion_minutos: [30, Validators.min(1)],
    hora_inicio: '08:00',
    hora_fin: '16:00',
    costo: ['0.00', Validators.pattern(/^\d{1,8}(\.\d{1,2})?$/)],
  });
  sedeId: number | null = null;
  servicioId: number | null = null;
  archivo: File | null = null;
  horarioSede = 0;
  dia = 1;
  readonly intervalos = this.fb.array<ReturnType<typeof this.intervalo>>([]);
  constructor() {
    this.cargar(true);
  }

  cargar(inicial = false) {
    if (inicial) this.resultado.set(null);
    this.ocupado.set(true);
    this.api.leer().subscribe({
      next: (data) => {
        this.datos.set(data);
        if (inicial) {
          this.colores.patchValue(data.identidad);
          this.direccion.setValue(this.urlEntrada(data.direccion));
        }
        this.ocupado.set(false);
      },
      error: (e) => {
        const previo = this.resultado();
        this.fallo(e, previo?.seccion ?? 'carga',
          previo ? previo.texto + ' No se pudo actualizar la vista.' : 'No se pudo cargar la configuración.');
      },
    });
  }
  private urlEntrada(host: string | null) {
    return host?.includes('.') ? 'https://' + host : host || '';
  }
  private fallo(e: HttpErrorResponse, seccion: Seccion, texto: string) {
    const d = e.error?.detail;
    const detalle = typeof d === 'string'
        ? d
        : Array.isArray(d)
          ? d.map((v) => v.msg).join(' · ')
          : 'Revise la conexión e intente nuevamente.';
    this.resultado.set({ seccion, tipo: 'error', texto: texto + ' ' + detalle });
    this.ocupado.set(false);
  }
  guardar(path: string, body: object, method: 'PUT' | 'POST' | 'PATCH' = 'PUT') {
    if (this.ocupado()) return;
    this.ocupado.set(true);
    this.resultado.set(null);
    const recurso = path.split('/')[0];
    const seccion = path.includes('/horarios/') ? 'horarios'
      : recurso === 'logo' ? 'identidad' : recurso === 'identidad' ? 'tema' : recurso as Seccion;
    const catalogo = seccion === 'sedes' ? 'sede' : 'servicio';
    const accion = {
      tema: 'Apariencia de mi panel',
      identidad: 'Logo',
      direccion: 'Dirección de acceso',
      horarios: 'Horario del día',
      sedes: '',
      servicios: '',
      carga: '',
    }[seccion] || (method === 'PATCH' ? 'Desactivación' : method === 'POST' ? 'Alta' : 'Edición') + ' de ' + catalogo;
    this.api.guardar(method, path, body).subscribe({
      next: () => {
        this.resultado.set({ seccion, tipo: 'exito', texto: accion + ' · cambios guardados.' });
        if (path === 'identidad' || path === 'logo') this.tenant.loadTenantContext().subscribe();
        if (path.startsWith('sedes') && !path.includes('horarios')) this.editarSede();
        if (path.startsWith('servicios')) this.editarServicio();
        this.cargar();
      },
      error: (e) => this.fallo(e, seccion, accion + ' · operación rechazada.'),
    });
  }
  seleccionarLogo(event: Event) {
    this.archivo = (event.target as HTMLInputElement).files?.[0] || null;
    this.resultado.set(null);
    if (
      this.archivo &&
      (this.archivo.size > 2097152 || !['image/png', 'image/jpeg'].includes(this.archivo.type))
    ) {
      this.resultado.set({
        seccion: 'identidad', tipo: 'error', texto: 'Logo rechazado. Seleccione un PNG o JPEG de hasta 2 MB.',
      });
      this.archivo = null;
    }
  }
  subir() {
    if (!this.archivo) return;
    const body = new FormData();
    body.set('archivo', this.archivo);
    this.guardar('logo', body);
  }
  editarSede(s?: Sede) {
    this.sedeId = s?.id ?? null;
    this.sede.reset(s || {});
  }
  editarServicio(s?: Servicio) {
    this.servicioId = s?.id ?? null;
    this.servicio.reset(s || {});
  }
  guardarSede() {
    if (this.sede.valid)
      this.guardar(
        this.sedeId ? 'sedes/' + this.sedeId : 'sedes',
        this.sede.getRawValue(),
        this.sedeId ? 'PUT' : 'POST',
      );
  }
  guardarServicio() {
    if (this.servicio.valid)
      this.guardar(
        this.servicioId ? 'servicios/' + this.servicioId : 'servicios',
        this.servicio.getRawValue(),
        this.servicioId ? 'PUT' : 'POST',
      );
  }
  intervalo(i?: Intervalo) {
    return this.fb.group({
      apertura: [i?.apertura || '08:00', Validators.required],
      cierre: [i?.cierre || '12:00', Validators.required],
    });
  }
  elegirHorario(sede: string, dia: string) {
    this.horarioSede = Number(sede);
    this.dia = Number(dia);
    this.intervalos.clear();
    for (const i of this.datos()?.horarios || []) {
      if (i.id_sede === this.horarioSede && i.dia === this.dia)
        this.intervalos.push(this.intervalo(i));
    }
  }
  guardarHorario() {
    const intervalos = this.intervalos
      .getRawValue()
      .sort((a, b) => a.apertura.localeCompare(b.apertura));
    if (
      intervalos.some(
        (v, i) =>
          v.apertura.slice(0, 5) >= v.cierre.slice(0, 5) ||
          (i > 0 && intervalos[i - 1].cierre.slice(0, 5) > v.apertura.slice(0, 5)),
      )
    ) {
      this.resultado.set({
        seccion: 'horarios', tipo: 'error',
        texto: 'Horario del día rechazado. Revise apertura y cierre. Los intervalos no pueden superponerse.',
      });
      return;
    }
    this.guardar('sedes/' + this.horarioSede + '/horarios/' + this.dia, { intervalos });
  }
}
