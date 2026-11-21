// Modelos CU07 Lista de espera (alineados a openspec/contracts/waitlist.md).
// fromJson tolerante camelCase/snake_case.

class InscripcionEsperaModel {
  final int idListaEspera;
  final int idPaciente;
  final String pacienteNombre;
  final int? idMedico;
  final String? medicoNombre;
  final int? idEspecialidad;
  final String? especialidadNombre;
  final String? fechaDeseada;
  final String estado;
  final int prioridad;
  final int posicion;
  final String? motivo;
  final int? idCitaOfrecida;
  final String? fechaCreacion;

  const InscripcionEsperaModel({
    required this.idListaEspera,
    required this.idPaciente,
    required this.pacienteNombre,
    this.idMedico,
    this.medicoNombre,
    this.idEspecialidad,
    this.especialidadNombre,
    this.fechaDeseada,
    required this.estado,
    required this.prioridad,
    required this.posicion,
    this.motivo,
    this.idCitaOfrecida,
    this.fechaCreacion,
  });

  factory InscripcionEsperaModel.fromJson(Map<String, dynamic> json) {
    return InscripcionEsperaModel(
      idListaEspera: json['idListaEspera'] ?? json['id_lista_espera'] ?? 0,
      idPaciente: json['idPaciente'] ?? json['id_paciente'] ?? 0,
      pacienteNombre: json['pacienteNombre'] ?? json['paciente_nombre'] ?? '',
      idMedico: json['idMedico'] ?? json['id_medico'],
      medicoNombre: json['medicoNombre'] ?? json['medico_nombre'],
      idEspecialidad: json['idEspecialidad'] ?? json['id_especialidad'],
      especialidadNombre: json['especialidadNombre'] ?? json['especialidad_nombre'],
      fechaDeseada: json['fechaDeseada'] ?? json['fecha_deseada'],
      estado: json['estado'] ?? 'EN_ESPERA',
      prioridad: json['prioridad'] ?? 0,
      posicion: json['posicion'] ?? 0,
      motivo: json['motivo'],
      idCitaOfrecida: json['idCitaOfrecida'] ?? json['id_cita_ofrecida'],
      fechaCreacion: json['fechaCreacion'] ?? json['fecha_creacion'],
    );
  }

  bool get estaEnEspera => estado == 'EN_ESPERA';
  bool get fueOfrecido => estado == 'OFRECIDO';
  bool get estaActiva => estaEnEspera || fueOfrecido;

  String get etiquetaEstado {
    switch (estado) {
      case 'EN_ESPERA':
        return 'En espera';
      case 'OFRECIDO':
        return 'Turno ofrecido';
      case 'CONFIRMADO':
        return 'Confirmado';
      case 'RECHAZADO':
        return 'Rechazado';
      case 'CANCELADO':
        return 'Cancelado';
      default:
        return estado;
    }
  }
}
