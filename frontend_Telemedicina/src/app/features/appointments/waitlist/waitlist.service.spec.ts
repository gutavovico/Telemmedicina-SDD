import { describe, it, expect } from 'vitest';
import { mapInscripcion, mapListaEsperaPage } from './waitlist.service';
import { etiquetaEstadoEspera } from '../../../core/models/waitlist.models';

describe('CU07 Lista de espera (mapeo snake_case → camelCase)', () => {
  it('mapea una inscripción del backend al contrato TS', () => {
    const dto = mapInscripcion({
      id_lista_espera: 10,
      id_paciente: 4,
      paciente_nombre: 'Ana Pérez',
      id_medico: 3,
      medico_nombre: 'Roberto Gómez Flores',
      id_especialidad: 2,
      especialidad_nombre: 'Cardiología',
      fecha_deseada: '2026-12-01',
      estado: 'EN_ESPERA',
      prioridad: 0,
      posicion: 1,
      motivo: 'Sin cupos en la fecha',
      id_cita_ofrecida: null,
      fecha_creacion: '2026-11-20T10:15:00',
    });
    expect(dto.idListaEspera).toBe(10);
    expect(dto.idPaciente).toBe(4);
    expect(dto.pacienteNombre).toBe('Ana Pérez');
    expect(dto.idMedico).toBe(3);
    expect(dto.medicoNombre).toBe('Roberto Gómez Flores');
    expect(dto.idEspecialidad).toBe(2);
    expect(dto.especialidadNombre).toBe('Cardiología');
    expect(dto.fechaDeseada).toBe('2026-12-01');
    expect(dto.estado).toBe('EN_ESPERA');
    expect(dto.posicion).toBe(1);
    expect(dto.idCitaOfrecida).toBeNull();
  });

  it('mapea la página y su tamaño', () => {
    const dto = mapListaEsperaPage({
      total: 1,
      page: 1,
      page_size: 50,
      items: [
        {
          id_lista_espera: 11,
          id_paciente: 5,
          paciente_nombre: 'Luis Paz',
          id_medico: null,
          medico_nombre: null,
          id_especialidad: 2,
          especialidad_nombre: 'Cardiología',
          fecha_deseada: null,
          estado: 'OFRECIDO',
          prioridad: 1,
          posicion: 1,
          motivo: null,
          id_cita_ofrecida: 77,
          fecha_creacion: '2026-11-20T11:00:00',
        },
      ],
    });
    expect(dto.total).toBe(1);
    expect(dto.pageSize).toBe(50);
    expect(dto.items).toHaveLength(1);
    expect(dto.items[0].idCitaOfrecida).toBe(77);
    expect(dto.items[0].estado).toBe('OFRECIDO');
  });

  it('expone etiquetas legibles para los estados', () => {
    expect(etiquetaEstadoEspera('EN_ESPERA')).toBe('En espera');
    expect(etiquetaEstadoEspera('OFRECIDO')).toBe('Turno ofrecido');
    expect(etiquetaEstadoEspera('CONFIRMADO')).toBe('Confirmado');
  });
});
