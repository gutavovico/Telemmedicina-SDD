class AppointmentModel {
  final int idCita;
  final int idPaciente;
  final int idMedico;
  final int? idEspecialidad;
  final String fechaCita;
  final String horaInicio;
  final String? horaFin;
  final String? motivo;
  final String estado;
  final String tipoConsulta;
  final String? notas;
  final String pacienteNombre;
  final String pacienteCi;
  final String pacienteIniciales;
  final String medicoNombre;
  final String especialidadNombre;
  final String? createdAt;
  final String? updatedAt;

  AppointmentModel({
    required this.idCita,
    required this.idPaciente,
    required this.idMedico,
    this.idEspecialidad,
    required this.fechaCita,
    required this.horaInicio,
    this.horaFin,
    this.motivo,
    required this.estado,
    this.tipoConsulta = 'TELEMEDICINA',
    this.notas,
    this.pacienteNombre = '',
    this.pacienteCi = '',
    this.pacienteIniciales = 'PA',
    this.medicoNombre = '',
    this.especialidadNombre = 'Consulta General',
    this.createdAt,
    this.updatedAt,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      idCita: json['id_cita'] is int ? json['id_cita'] : int.tryParse(json['id_cita']?.toString() ?? '0') ?? 0,
      idPaciente: json['id_paciente'] is int ? json['id_paciente'] : int.tryParse(json['id_paciente']?.toString() ?? '0') ?? 0,
      idMedico: json['id_medico'] is int ? json['id_medico'] : int.tryParse(json['id_medico']?.toString() ?? '0') ?? 0,
      idEspecialidad: json['id_especialidad'] != null ? int.tryParse(json['id_especialidad'].toString()) : null,
      fechaCita: json['fecha_cita']?.toString() ?? '',
      horaInicio: json['hora_inicio']?.toString() ?? '09:00',
      horaFin: json['hora_fin']?.toString(),
      motivo: json['motivo']?.toString(),
      estado: json['estado']?.toString().toUpperCase() ?? 'PENDIENTE',
      tipoConsulta: json['tipo_consulta']?.toString() ?? 'TELEMEDICINA',
      notas: json['notas']?.toString(),
      pacienteNombre: json['paciente_nombre']?.toString() ?? 'Paciente',
      pacienteCi: json['paciente_ci']?.toString() ?? '',
      pacienteIniciales: json['paciente_iniciales']?.toString() ?? 'PA',
      medicoNombre: json['medico_nombre']?.toString() ?? 'Médico',
      especialidadNombre: json['especialidad_nombre']?.toString() ?? 'Medicina General',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_paciente': idPaciente,
      'id_medico': idMedico,
      if (idEspecialidad != null) 'id_especialidad': idEspecialidad,
      'fecha_cita': fechaCita,
      'hora_inicio': horaInicio,
      if (horaFin != null) 'hora_fin': horaFin,
      if (motivo != null) 'motivo': motivo,
      'estado': estado,
      'tipo_consulta': tipoConsulta,
      if (notas != null) 'notas': notas,
    };
  }

  AppointmentModel copyWith({
    int? idCita,
    int? idPaciente,
    int? idMedico,
    int? idEspecialidad,
    String? fechaCita,
    String? horaInicio,
    String? horaFin,
    String? motivo,
    String? estado,
    String? tipoConsulta,
    String? notas,
    String? pacienteNombre,
    String? pacienteCi,
    String? pacienteIniciales,
    String? medicoNombre,
    String? especialidadNombre,
  }) {
    return AppointmentModel(
      idCita: idCita ?? this.idCita,
      idPaciente: idPaciente ?? this.idPaciente,
      idMedico: idMedico ?? this.idMedico,
      idEspecialidad: idEspecialidad ?? this.idEspecialidad,
      fechaCita: fechaCita ?? this.fechaCita,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      motivo: motivo ?? this.motivo,
      estado: estado ?? this.estado,
      tipoConsulta: tipoConsulta ?? this.tipoConsulta,
      notas: notas ?? this.notas,
      pacienteNombre: pacienteNombre ?? this.pacienteNombre,
      pacienteCi: pacienteCi ?? this.pacienteCi,
      pacienteIniciales: pacienteIniciales ?? this.pacienteIniciales,
      medicoNombre: medicoNombre ?? this.medicoNombre,
      especialidadNombre: especialidadNombre ?? this.especialidadNombre,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

