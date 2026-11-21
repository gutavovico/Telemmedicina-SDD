export interface Intervalo {
  apertura: string;
  cierre: string;
}
export interface Sede {
  id: number;
  nombre: string;
  ubicacion: string;
  activa: boolean;
}
export interface Servicio {
  id: number;
  nombre: string;
  modalidad: string;
  duracion_minutos: number;
  costo: string;
  hora_inicio: string;
  hora_fin: string;
  estado: string;
}
export interface Configuracion {
  identidad: { principal: string; secundario: string; logo: string | null };
  direccion: string | null;
  sedes: Sede[];
  servicios: Servicio[];
  horarios: (Intervalo & { id_sede: number; dia: number })[];
}
