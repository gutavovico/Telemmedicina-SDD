import '../../domain/entities/ficha_entity.dart';

class FichaModel extends FichaEntity {
  const FichaModel({
    required super.idFicha,
    required super.idClinica,
    required super.correlativo,
    required super.idPaciente,
    super.pacienteNombre,
    super.pacienteCi,
    required super.idMedico,
    super.medicoNombre,
    super.idServicio,
    super.servicioNombre,
    super.idEspecialidad,
    super.especialidadNombre,
    super.idCita,
    required super.fechaEmision,
    required super.fechaAtencion,
    required super.horaInicio,
    required super.horaFin,
    required super.motivoConsulta,
    super.signosVitales = const {},
    super.seccionesDinamicas = const {},
    super.codigoCie10,
    super.diagnosticoDescripcion,
    super.notasEvolucion,
    required super.estado,
    super.motivoCancelacion,
    required super.createdAt,
  });

  factory FichaModel.fromJson(Map<String, dynamic> json) {
    return FichaModel(
      idFicha: (json['id_ficha'] ?? '').toString(),
      idClinica: json['id_clinica'] ?? json['tenant_id'] ?? 1,
      correlativo: (json['correlativo'] ?? '').toString(),
      idPaciente: json['id_paciente'] ?? json['paciente_id'] ?? 0,
      pacienteNombre: json['paciente_nombre']?.toString(),
      pacienteCi: json['paciente_ci']?.toString(),
      idMedico: json['id_medico'] ?? json['medico_id'] ?? 0,
      medicoNombre: json['medico_nombre']?.toString(),
      idServicio: json['id_servicio'] ?? json['servicio_id'],
      servicioNombre: json['servicio_nombre']?.toString(),
      idEspecialidad: json['id_especialidad'] ?? json['especialidad_id'],
      especialidadNombre: json['especialidad_nombre']?.toString(),
      idCita: json['id_cita'] ?? json['cita_id'],
      fechaEmision: json['fecha_emision'] != null
          ? DateTime.tryParse(json['fecha_emision'].toString()) ?? DateTime.now()
          : DateTime.now(),
      fechaAtencion: (json['fecha_atencion'] ?? '').toString(),
      horaInicio: (json['hora_inicio'] ?? '').toString(),
      horaFin: (json['hora_fin'] ?? '').toString(),
      motivoConsulta: (json['motivo_consulta'] ?? '').toString(),
      signosVitales: json['signos_vitales'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['signos_vitales'] as Map)
          : {},
      seccionesDinamicas: json['secciones_dinamicas'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['secciones_dinamicas'] as Map)
          : {},
      codigoCie10: json['codigo_cie10']?.toString(),
      diagnosticoDescripcion: json['diagnostico_descripcion']?.toString(),
      notasEvolucion: json['notas_evolucion']?.toString(),
      estado: (json['estado'] ?? 'EMITIDA').toString(),
      motivoCancelacion: json['motivo_cancelacion']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_ficha': idFicha,
      'id_clinica': idClinica,
      'correlativo': correlativo,
      'id_paciente': idPaciente,
      'id_medico': idMedico,
      if (idServicio != null) 'id_servicio': idServicio,
      if (idEspecialidad != null) 'id_especialidad': idEspecialidad,
      if (idCita != null) 'id_cita': idCita,
      'fecha_atencion': fechaAtencion,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'motivo_consulta': motivoConsulta,
      'signos_vitales': signosVitales,
      'secciones_dinamicas': seccionesDinamicas,
      if (codigoCie10 != null) 'codigo_cie10': codigoCie10,
      if (diagnosticoDescripcion != null) 'diagnostico_descripcion': diagnosticoDescripcion,
      if (notasEvolucion != null) 'notas_evolucion': notasEvolucion,
      'estado': estado,
    };
  }
}
