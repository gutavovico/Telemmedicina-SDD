// DTOs CU07 Lista de espera (derivan de openspec/contracts/waitlist.md). Sin `any`.
export type EstadoEspera =
  | 'EN_ESPERA'
  | 'OFRECIDO'
  | 'CONFIRMADO'
  | 'RECHAZADO'
  | 'CANCELADO'
  | 'EXPIRADO';

export interface InscripcionEsperaDTO {
  idListaEspera: number;
  idPaciente: number;
  pacienteNombre: string;
  idMedico: number | null;
  medicoNombre: string | null;
  idEspecialidad: number | null;
  especialidadNombre: string | null;
  fechaDeseada: string | null;
  estado: EstadoEspera;
  prioridad: number;
  posicion: number;
  motivo: string | null;
  idCitaOfrecida: number | null;
  fechaCreacion: string | null;
}

export interface ListaEsperaPageDTO {
  total: number;
  page: number;
  pageSize: number;
  items: InscripcionEsperaDTO[];
}

export interface InscripcionEsperaCommand {
  idPaciente?: number;
  idMedico?: number;
  idEspecialidad?: number;
  fechaDeseada?: string;
  prioridad?: number;
  motivo?: string;
}

export interface OfrecerTurnoCommand {
  fecha: string;
  horaInicio: string;
  horaFin?: string;
  idMedico?: number;
}

/** Etiquetas legibles para los estados de la lista de espera. */
export function etiquetaEstadoEspera(estado: EstadoEspera): string {
  const etiquetas: Record<EstadoEspera, string> = {
    EN_ESPERA: 'En espera',
    OFRECIDO: 'Turno ofrecido',
    CONFIRMADO: 'Confirmado',
    RECHAZADO: 'Rechazado',
    CANCELADO: 'Cancelado',
    EXPIRADO: 'Expirado',
  };
  return etiquetas[estado] ?? estado;
}
