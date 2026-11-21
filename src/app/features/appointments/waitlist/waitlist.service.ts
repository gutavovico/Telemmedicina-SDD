import { Injectable, computed, inject, signal } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { environment } from '../../../../environments/environment';
import type {
  InscripcionEsperaCommand,
  InscripcionEsperaDTO,
  ListaEsperaPageDTO,
  OfrecerTurnoCommand,
} from '../../../core/models/waitlist.models';

interface InscripcionApi {
  id_lista_espera: number;
  id_paciente: number;
  paciente_nombre: string;
  id_medico: number | null;
  medico_nombre: string | null;
  id_especialidad: number | null;
  especialidad_nombre: string | null;
  fecha_deseada: string | null;
  estado: string;
  prioridad: number;
  posicion: number;
  motivo: string | null;
  id_cita_ofrecida: number | null;
  fecha_creacion: string | null;
}

interface PageApi {
  total: number;
  page: number;
  page_size: number;
  items: InscripcionApi[];
}

/** Mapeo snake_case (backend) -> camelCase (contrato TS). Exportado para specs. */
export function mapInscripcion(api: InscripcionApi): InscripcionEsperaDTO {
  return {
    idListaEspera: api.id_lista_espera,
    idPaciente: api.id_paciente,
    pacienteNombre: api.paciente_nombre,
    idMedico: api.id_medico,
    medicoNombre: api.medico_nombre,
    idEspecialidad: api.id_especialidad,
    especialidadNombre: api.especialidad_nombre,
    fechaDeseada: api.fecha_deseada,
    estado: api.estado as InscripcionEsperaDTO['estado'],
    prioridad: api.prioridad,
    posicion: api.posicion,
    motivo: api.motivo,
    idCitaOfrecida: api.id_cita_ofrecida,
    fechaCreacion: api.fecha_creacion,
  };
}

/** Mapeo de pagina snake_case -> camelCase. Exportado para specs. */
export function mapListaEsperaPage(api: PageApi): ListaEsperaPageDTO {
  return {
    total: api.total,
    page: api.page,
    pageSize: api.page_size,
    items: (api.items ?? []).map(mapInscripcion),
  };
}

function toCommand(cmd: InscripcionEsperaCommand): Record<string, unknown> {
  return {
    id_paciente: cmd.idPaciente,
    id_medico: cmd.idMedico,
    id_especialidad: cmd.idEspecialidad,
    fecha_deseada: cmd.fechaDeseada,
    prioridad: cmd.prioridad,
    motivo: cmd.motivo,
  };
}

function toOfrecerCommand(cmd: OfrecerTurnoCommand): Record<string, unknown> {
  return {
    fecha: cmd.fecha,
    hora_inicio: cmd.horaInicio,
    hora_fin: cmd.horaFin,
    id_medico: cmd.idMedico,
  };
}

function mensajeError(err: { error?: { detail?: string } } | null): string {
  return err?.error?.detail ?? 'No se pudo completar la operación.';
}

@Injectable({ providedIn: 'root' })
export class WaitlistService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = `${environment.apiUrl}/api/v1/lista-espera`;

  private readonly _mias = signal<InscripcionEsperaDTO[]>([]);
  private readonly _pagina = signal<ListaEsperaPageDTO | null>(null);
  private readonly _cargando = signal(false);
  private readonly _error = signal<string | null>(null);
  private readonly _accionEnCurso = signal(false);

  readonly mias = computed(() => this._mias());
  readonly pagina = computed(() => this._pagina());
  readonly cargando = computed(() => this._cargando());
  readonly error = computed(() => this._error());
  readonly accionEnCurso = computed(() => this._accionEnCurso());

  cargarMias(): void {
    this._cargando.set(true);
    this._error.set(null);
    this.http.get<InscripcionApi[]>(`${this.apiUrl}/mi-espera`).subscribe({
      next: (data) => {
        this._mias.set((data ?? []).map(mapInscripcion));
        this._cargando.set(false);
      },
      error: (err) => {
        this._cargando.set(false);
        this._error.set(mensajeError(err));
      },
    });
  }

  listar(filtros: {
    estado?: string;
    idMedico?: number;
    idEspecialidad?: number;
    fechaDeseada?: string;
    page?: number;
    pageSize?: number;
  } = {}): void {
    this._cargando.set(true);
    this._error.set(null);
    let params = new HttpParams();
    if (filtros.estado) params = params.set('estado', filtros.estado);
    if (filtros.idMedico) params = params.set('id_medico', String(filtros.idMedico));
    if (filtros.idEspecialidad) params = params.set('id_especialidad', String(filtros.idEspecialidad));
    if (filtros.fechaDeseada) params = params.set('fecha_deseada', filtros.fechaDeseada);
    params = params.set('page', String(filtros.page ?? 1));
    params = params.set('page_size', String(filtros.pageSize ?? 50));

    this.http.get<PageApi>(this.apiUrl, { params }).subscribe({
      next: (data) => {
        this._pagina.set(mapListaEsperaPage(data));
        this._cargando.set(false);
      },
      error: (err) => {
        this._cargando.set(false);
        this._error.set(mensajeError(err));
      },
    });
  }

  inscribirse(cmd: InscripcionEsperaCommand, onDone?: () => void): void {
    this._accionEnCurso.set(true);
    this._error.set(null);
    this.http.post<InscripcionApi>(this.apiUrl, toCommand(cmd)).subscribe({
      next: () => {
        this._accionEnCurso.set(false);
        onDone?.();
      },
      error: (err) => {
        this._accionEnCurso.set(false);
        this._error.set(mensajeError(err));
      },
    });
  }

  salir(id: number, onDone?: () => void): void {
    this._accion(id, 'delete', onDone);
  }

  confirmar(id: number, onDone?: () => void): void {
    this._accion(id, 'confirmar', onDone);
  }

  rechazar(id: number, onDone?: () => void): void {
    this._accion(id, 'rechazar', onDone);
  }

  ofrecer(id: number, cmd: OfrecerTurnoCommand, onDone?: () => void): void {
    this._accionEnCurso.set(true);
    this._error.set(null);
    this.http
      .post<InscripcionApi>(`${this.apiUrl}/${id}/ofrecer`, toOfrecerCommand(cmd))
      .subscribe({
        next: () => {
          this._accionEnCurso.set(false);
          onDone?.();
        },
        error: (err) => {
          this._accionEnCurso.set(false);
          this._error.set(mensajeError(err));
        },
      });
  }

  limpiarError(): void {
    this._error.set(null);
  }

  private _accion(id: number, accion: 'delete' | 'confirmar' | 'rechazar', onDone?: () => void): void {
    this._accionEnCurso.set(true);
    this._error.set(null);
    const url = accion === 'delete' ? `${this.apiUrl}/${id}` : `${this.apiUrl}/${id}/${accion}`;
    const request$ =
      accion === 'delete' ? this.http.delete<InscripcionApi>(url) : this.http.post<InscripcionApi>(url, {});
    request$.subscribe({
      next: () => {
        this._accionEnCurso.set(false);
        onDone?.();
      },
      error: (err) => {
        this._accionEnCurso.set(false);
        this._error.set(mensajeError(err));
      },
    });
  }
}
