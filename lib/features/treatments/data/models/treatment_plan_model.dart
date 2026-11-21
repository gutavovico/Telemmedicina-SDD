import '../../domain/entities/treatment_entities.dart';
import 'adherencia_model.dart';
import 'medicamento_plan_model.dart';

class DiagnosticoModel {
  final String? codigoCie;
  final String? descripcion;

  const DiagnosticoModel({
    this.codigoCie,
    this.descripcion,
  });

  factory DiagnosticoModel.fromJson(Map<String, dynamic> json) {
    return DiagnosticoModel(
      codigoCie: json['codigo_cie'] as String?,
      descripcion: json['descripcion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo_cie': codigoCie,
      'descripcion': descripcion,
    };
  }

  Diagnostico toEntity() {
    return Diagnostico(
      codigoCie: codigoCie,
      descripcion: descripcion,
    );
  }

  factory DiagnosticoModel.fromEntity(Diagnostico entity) {
    return DiagnosticoModel(
      codigoCie: entity.codigoCie,
      descripcion: entity.descripcion,
    );
  }
}

class TreatmentPlanModel {
  final int idTratamiento;
  final int idClinica;
  final int idConsulta;
  final int? idReceta;
  final int? idDiagnostico;
  final DiagnosticoModel? diagnostico;
  final int idPaciente;
  final int idMedico;
  final String fechaInicio;
  final String fechaFin;
  final String zonaHoraria;
  final String estado;
  final String? notas;
  final String? motivoCierre;
  final List<MedicamentoPlanModel> medicamentos;
  final String? createdAt;
  final String? updatedAt;
  final AdherenciaModel? adherencia;

  const TreatmentPlanModel({
    required this.idTratamiento,
    required this.idClinica,
    required this.idConsulta,
    this.idReceta,
    this.idDiagnostico,
    this.diagnostico,
    required this.idPaciente,
    required this.idMedico,
    required this.fechaInicio,
    required this.fechaFin,
    required this.zonaHoraria,
    required this.estado,
    this.notas,
    this.motivoCierre,
    required this.medicamentos,
    this.createdAt,
    this.updatedAt,
    this.adherencia,
  });

  factory TreatmentPlanModel.fromJson(Map<String, dynamic> json) {
    return TreatmentPlanModel(
      idTratamiento: (json['id_tratamiento'] as num?)?.toInt() ?? 0,
      idClinica: (json['id_clinica'] as num?)?.toInt() ?? 0,
      idConsulta: (json['id_consulta'] as num?)?.toInt() ?? 0,
      idReceta: (json['id_receta'] as num?)?.toInt(),
      idDiagnostico: (json['id_diagnostico'] as num?)?.toInt(),
      diagnostico: json['diagnostico'] != null && json['diagnostico'] is Map
          ? DiagnosticoModel.fromJson(
              Map<String, dynamic>.from(json['diagnostico'] as Map))
          : null,
      idPaciente: (json['id_paciente'] as num?)?.toInt() ?? 0,
      idMedico: (json['id_medico'] as num?)?.toInt() ?? 0,
      fechaInicio: (json['fecha_inicio'] as String?)?.trim() ?? '',
      fechaFin: (json['fecha_fin'] as String?)?.trim() ?? '',
      zonaHoraria: (json['zona_horaria'] as String?)?.trim() ?? '',
      estado: (json['estado'] as String?)?.trim() ?? 'ACTIVO',
      notas: json['notas'] as String?,
      motivoCierre: json['motivo_cierre'] as String?,
      medicamentos: (json['medicamentos'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => MedicamentoPlanModel.fromJson(
                  Map<String, dynamic>.from(e)))
              .toList() ??
          <MedicamentoPlanModel>[],
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      adherencia: json['adherencia'] != null && json['adherencia'] is Map
          ? AdherenciaModel.fromJson(
              Map<String, dynamic>.from(json['adherencia'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_tratamiento': idTratamiento,
      'id_clinica': idClinica,
      'id_consulta': idConsulta,
      'id_receta': idReceta,
      'id_diagnostico': idDiagnostico,
      'diagnostico': diagnostico?.toJson(),
      'id_paciente': idPaciente,
      'id_medico': idMedico,
      'fecha_inicio': fechaInicio,
      'fecha_fin': fechaFin,
      'zona_horaria': zonaHoraria,
      'estado': estado,
      'notas': notas,
      'motivo_cierre': motivoCierre,
      'medicamentos': medicamentos.map((m) => m.toJson()).toList(),
      'created_at': createdAt,
      'updated_at': updatedAt,
      'adherencia': adherencia?.toJson(),
    };
  }

  TreatmentPlan toEntity() {
    return TreatmentPlan(
      idTratamiento: idTratamiento,
      idClinica: idClinica,
      idConsulta: idConsulta,
      idReceta: idReceta,
      idDiagnostico: idDiagnostico,
      diagnostico: diagnostico?.toEntity(),
      idPaciente: idPaciente,
      idMedico: idMedico,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      zonaHoraria: zonaHoraria,
      estado: estado,
      notas: notas,
      motivoCierre: motivoCierre,
      medicamentos: medicamentos.map((m) => m.toEntity()).toList(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      adherencia: adherencia?.toEntity(),
    );
  }

  factory TreatmentPlanModel.fromEntity(TreatmentPlan entity) {
    return TreatmentPlanModel(
      idTratamiento: entity.idTratamiento,
      idClinica: entity.idClinica,
      idConsulta: entity.idConsulta,
      idReceta: entity.idReceta,
      idDiagnostico: entity.idDiagnostico,
      diagnostico: entity.diagnostico != null
          ? DiagnosticoModel.fromEntity(entity.diagnostico!)
          : null,
      idPaciente: entity.idPaciente,
      idMedico: entity.idMedico,
      fechaInicio: entity.fechaInicio,
      fechaFin: entity.fechaFin,
      zonaHoraria: entity.zonaHoraria,
      estado: entity.estado,
      notas: entity.notas,
      motivoCierre: entity.motivoCierre,
      medicamentos: entity.medicamentos
          .map((m) => MedicamentoPlanModel.fromEntity(m))
          .toList(),
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      adherencia: entity.adherencia != null
          ? AdherenciaModel.fromEntity(entity.adherencia!)
          : null,
    );
  }
}

class TreatmentPlanListResponse {
  final List<TreatmentPlanModel> items;
  final int total;

  const TreatmentPlanListResponse({
    required this.items,
    required this.total,
  });

  factory TreatmentPlanListResponse.fromJson(Map<String, dynamic> json) {
    return TreatmentPlanListResponse(
      items: (json['items'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => TreatmentPlanModel.fromJson(
                  Map<String, dynamic>.from(e)))
              .toList() ??
          <TreatmentPlanModel>[],
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'total': total,
    };
  }
}
