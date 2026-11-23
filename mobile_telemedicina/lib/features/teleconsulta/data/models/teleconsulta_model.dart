import 'chat_message_model.dart';

class PatientSummaryModel {
  final int idPaciente;
  final String nombreCompleto;
  final String identificacionId;
  final String inicialesAvatar;
  final String seguroProveedor;
  final String seguroPoliza;

  const PatientSummaryModel({
    required this.idPaciente,
    required this.nombreCompleto,
    required this.identificacionId,
    required this.inicialesAvatar,
    required this.seguroProveedor,
    required this.seguroPoliza,
  });

  factory PatientSummaryModel.fromJson(Map<String, dynamic> json) {
    return PatientSummaryModel(
      idPaciente: json['idPaciente'] as int? ?? json['id_paciente'] as int? ?? 0,
      nombreCompleto: json['nombreCompleto'] as String? ?? json['nombre_completo'] as String? ?? 'Paciente',
      identificacionId: json['identificacionId'] as String? ?? json['identificacion_id'] as String? ?? '',
      inicialesAvatar: json['inicialesAvatar'] as String? ?? json['iniciales_avatar'] as String? ?? 'PA',
      seguroProveedor: json['seguroProveedor'] as String? ?? json['seguro_proveedor'] as String? ?? '',
      seguroPoliza: json['seguroPoliza'] as String? ?? json['seguro_poliza'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idPaciente': idPaciente,
      'nombreCompleto': nombreCompleto,
      'identificacionId': identificacionId,
      'inicialesAvatar': inicialesAvatar,
      'seguroProveedor': seguroProveedor,
      'seguroPoliza': seguroPoliza,
    };
  }
}

class AppointmentDetailsModel {
  final int idCita;
  final String nombreMedico;
  final String especialidad;
  final String rangoFechas;
  final String horaTeleconsulta;
  final String modalidad;
  final String estado;

  const AppointmentDetailsModel({
    required this.idCita,
    required this.nombreMedico,
    required this.especialidad,
    required this.rangoFechas,
    required this.horaTeleconsulta,
    required this.modalidad,
    required this.estado,
  });

  factory AppointmentDetailsModel.fromJson(Map<String, dynamic> json) {
    return AppointmentDetailsModel(
      idCita: json['idCita'] as int? ?? json['id_cita'] as int? ?? 0,
      nombreMedico: json['nombreMedico'] as String? ?? json['nombre_medico'] as String? ?? 'Dr. Especialista',
      especialidad: json['especialidad'] as String? ?? 'Medicina General',
      rangoFechas: json['rangoFechas'] as String? ?? json['rango_fechas'] as String? ?? '',
      horaTeleconsulta: json['horaTeleconsulta'] as String? ?? json['hora_teleconsulta'] as String? ?? '',
      modalidad: json['modalidad'] as String? ?? 'TELEMEDICINA',
      estado: json['estado'] as String? ?? 'CONFIRMADA',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idCita': idCita,
      'nombreMedico': nombreMedico,
      'especialidad': especialidad,
      'rangoFechas': rangoFechas,
      'horaTeleconsulta': horaTeleconsulta,
      'modalidad': modalidad,
      'estado': estado,
    };
  }
}

class DoctorProfileSummaryModel {
  final int idMedico;
  final String nombreCompleto;
  final String cargoEtiqueta;
  final String biografia;
  final String? fotoUrl;
  final String estadoDisponibilidad;

  const DoctorProfileSummaryModel({
    required this.idMedico,
    required this.nombreCompleto,
    required this.cargoEtiqueta,
    required this.biografia,
    this.fotoUrl,
    required this.estadoDisponibilidad,
  });

  factory DoctorProfileSummaryModel.fromJson(Map<String, dynamic> json) {
    return DoctorProfileSummaryModel(
      idMedico: json['idMedico'] as int? ?? json['id_medico'] as int? ?? 0,
      nombreCompleto: json['nombreCompleto'] as String? ?? json['nombre_completo'] as String? ?? 'Dr. Especialista',
      cargoEtiqueta: json['cargoEtiqueta'] as String? ?? json['cargo_etiqueta'] as String? ?? 'Su Médico',
      biografia: json['biografia'] as String? ?? '',
      fotoUrl: json['fotoUrl'] as String? ?? json['foto_url'] as String?,
      estadoDisponibilidad: json['estadoDisponibilidad'] as String? ?? json['estado_disponibilidad'] as String? ?? 'DISPONIBLE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idMedico': idMedico,
      'nombreCompleto': nombreCompleto,
      'cargoEtiqueta': cargoEtiqueta,
      'biografia': biografia,
      if (fotoUrl != null) 'fotoUrl': fotoUrl,
      'estadoDisponibilidad': estadoDisponibilidad,
    };
  }
}

class TeleconsultaViewModel {
  final String nombreClinica;
  final Map<String, dynamic>? usuarioActivo;
  final PatientSummaryModel? paciente;
  final AppointmentDetailsModel? cita;
  final DoctorProfileSummaryModel? medico;
  final List<ChatMessageModel> mensajes;

  const TeleconsultaViewModel({
    required this.nombreClinica,
    this.usuarioActivo,
    this.paciente,
    this.cita,
    this.medico,
    required this.mensajes,
  });

  factory TeleconsultaViewModel.fromJson(Map<String, dynamic> json) {
    final rawMensajes = json['mensajes'] as List<dynamic>? ?? [];
    final mensajesParsed = rawMensajes
        .map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>))
        .toList();

    return TeleconsultaViewModel(
      nombreClinica: json['nombreClinica'] as String? ?? json['nombre_clinica'] as String? ?? 'Hospital San Juan de Dios',
      usuarioActivo: json['usuarioActivo'] as Map<String, dynamic>?,
      paciente: json['paciente'] != null
          ? PatientSummaryModel.fromJson(json['paciente'] as Map<String, dynamic>)
          : null,
      cita: json['cita'] != null
          ? AppointmentDetailsModel.fromJson(json['cita'] as Map<String, dynamic>)
          : null,
      medico: json['medico'] != null
          ? DoctorProfileSummaryModel.fromJson(json['medico'] as Map<String, dynamic>)
          : null,
      mensajes: mensajesParsed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombreClinica': nombreClinica,
      if (usuarioActivo != null) 'usuarioActivo': usuarioActivo,
      if (paciente != null) 'paciente': paciente!.toJson(),
      if (cita != null) 'cita': cita!.toJson(),
      if (medico != null) 'medico': medico!.toJson(),
      'mensajes': mensajes.map((m) => m.toJson()).toList(),
    };
  }
}
