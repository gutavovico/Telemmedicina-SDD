// Modelos CU08 Live Queue (alineados a openspec/contracts/live-queue.md).
// fromJson tolerante camelCase/snake_case, como teleconsulta_model.dart.

class MiTurnoModel {
  final int idCita;
  final String hora;
  final String estado;
  final int posicion;
  final int etaMinutos;
  final int delante;
  final bool proximo;
  final String estadoCola;
  final String? mensajeCola;
  final String medicoNombre;
  final String fecha;

  const MiTurnoModel({
    required this.idCita,
    required this.hora,
    required this.estado,
    required this.posicion,
    required this.etaMinutos,
    required this.delante,
    required this.proximo,
    required this.estadoCola,
    this.mensajeCola,
    required this.medicoNombre,
    required this.fecha,
  });

  factory MiTurnoModel.fromJson(Map<String, dynamic> json) {
    return MiTurnoModel(
      idCita: json['idCita'] ?? json['id_cita'] ?? 0,
      hora: json['hora'] ?? '--:--',
      estado: json['estado'] ?? 'SIN_TURNOS',
      posicion: json['posicion'] ?? 0,
      etaMinutos: json['etaMinutos'] ?? json['eta_minutos'] ?? 0,
      delante: json['delante'] ?? 0,
      proximo: json['proximo'] ?? false,
      estadoCola: json['estadoCola'] ?? json['estado_cola'] ?? 'SIN_TURNOS',
      mensajeCola: json['mensajeCola'] ?? json['mensaje_cola'],
      medicoNombre: json['medicoNombre'] ?? json['medico_nombre'] ?? '',
      fecha: json['fecha'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idCita': idCita,
      'hora': hora,
      'estado': estado,
      'posicion': posicion,
      'etaMinutos': etaMinutos,
      'delante': delante,
      'proximo': proximo,
      'estadoCola': estadoCola,
      'mensajeCola': mensajeCola,
      'medicoNombre': medicoNombre,
      'fecha': fecha,
    };
  }
}

class EntradaColaModel {
  final int idCita;
  final String hora;
  final String estado;
  final int posicion;
  final int etaMinutos;
  final String pacienteNombre;
  final String? checkIn;

  const EntradaColaModel({
    required this.idCita,
    required this.hora,
    required this.estado,
    required this.posicion,
    required this.etaMinutos,
    required this.pacienteNombre,
    this.checkIn,
  });

  factory EntradaColaModel.fromJson(Map<String, dynamic> json) {
    return EntradaColaModel(
      idCita: json['idCita'] ?? json['id_cita'] ?? 0,
      hora: json['hora'] ?? '--:--',
      estado: json['estado'] ?? 'PENDIENTE',
      posicion: json['posicion'] ?? 0,
      etaMinutos: json['etaMinutos'] ?? json['eta_minutos'] ?? 0,
      pacienteNombre: json['pacienteNombre'] ?? json['paciente_nombre'] ?? '',
      checkIn: json['checkIn'] ?? json['check_in'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idCita': idCita,
      'hora': hora,
      'estado': estado,
      'posicion': posicion,
      'etaMinutos': etaMinutos,
      'pacienteNombre': pacienteNombre,
      'checkIn': checkIn,
    };
  }
}

class ColaOperativaModel {
  final int idMedico;
  final String medicoNombre;
  final String fecha;
  final String estadoCola;
  final String? mensajeCola;
  final int duracionPromedioMin;
  final int totalPendientes;
  final List<EntradaColaModel> entradas;

  const ColaOperativaModel({
    required this.idMedico,
    required this.medicoNombre,
    required this.fecha,
    required this.estadoCola,
    this.mensajeCola,
    required this.duracionPromedioMin,
    required this.totalPendientes,
    required this.entradas,
  });

  factory ColaOperativaModel.fromJson(Map<String, dynamic> json) {
    final raw = json['entradas'] ?? json['entradasCola'] ?? [];
    return ColaOperativaModel(
      idMedico: json['idMedico'] ?? json['id_medico'] ?? 0,
      medicoNombre: json['medicoNombre'] ?? json['medico_nombre'] ?? '',
      fecha: json['fecha'] ?? '',
      estadoCola: json['estadoCola'] ?? json['estado_cola'] ?? 'SIN_TURNOS',
      mensajeCola: json['mensajeCola'] ?? json['mensaje_cola'],
      duracionPromedioMin: json['duracionPromedioMin'] ?? json['duracion_promedio_min'] ?? 20,
      totalPendientes: json['totalPendientes'] ?? json['total_pendientes'] ?? 0,
      entradas: (raw as List)
          .whereType<Map<String, dynamic>>()
          .map(EntradaColaModel.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idMedico': idMedico,
      'medicoNombre': medicoNombre,
      'fecha': fecha,
      'estadoCola': estadoCola,
      'mensajeCola': mensajeCola,
      'duracionPromedioMin': duracionPromedioMin,
      'totalPendientes': totalPendientes,
      'entradas': entradas.map((e) => e.toJson()).toList(),
    };
  }
}
