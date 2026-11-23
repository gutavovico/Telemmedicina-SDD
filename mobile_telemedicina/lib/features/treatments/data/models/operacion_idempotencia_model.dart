import '../../domain/entities/treatment_entities.dart';
import 'dosis_model.dart';

class OperacionIdempotenciaModel {
  final int idDosis;
  final String idempotencyKey;
  final String estado;
  final bool confirmado;
  final bool enCurso;
  final bool rechazado;
  final DosisModel? dosis;
  final String? mensaje;
  final int? generacion;

  const OperacionIdempotenciaModel({
    required this.idDosis,
    required this.idempotencyKey,
    required this.estado,
    required this.confirmado,
    required this.enCurso,
    required this.rechazado,
    this.dosis,
    this.mensaje,
    this.generacion,
  });

  factory OperacionIdempotenciaModel.fromJson(Map<String, dynamic> json) {
    return OperacionIdempotenciaModel(
      idDosis: (json['id_dosis'] as num?)?.toInt() ?? 0,
      idempotencyKey: (json['idempotency_key'] as String?)?.trim() ?? '',
      estado: (json['estado'] as String?)?.trim() ?? '',
      confirmado: json['confirmado'] as bool? ?? false,
      enCurso: json['en_curso'] as bool? ?? false,
      rechazado: json['rechazado'] as bool? ?? false,
      dosis: json['dosis'] != null && json['dosis'] is Map
          ? DosisModel.fromJson(Map<String, dynamic>.from(json['dosis'] as Map))
          : null,
      mensaje: json['mensaje'] as String?,
      generacion: (json['generacion'] as num?)?.toInt(),
    );
  }

  factory OperacionIdempotenciaModel.fromRegistroDosisResponse(
    Map<String, dynamic> json, {
    required String idempotencyKey,
    int? generacion,
  }) {
    final Map<String, dynamic> doseMap = json['dosis'] is Map
        ? Map<String, dynamic>.from(json['dosis'] as Map)
        : json;
    final dosis = DosisModel.fromJson(doseMap);
    return OperacionIdempotenciaModel(
      idDosis: dosis.idDosis,
      idempotencyKey: idempotencyKey,
      estado: 'CONFIRMADA',
      confirmado: true,
      enCurso: false,
      rechazado: false,
      dosis: dosis,
      generacion: generacion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_dosis': idDosis,
      'idempotency_key': idempotencyKey,
      'estado': estado,
      'confirmado': confirmado,
      'en_curso': enCurso,
      'rechazado': rechazado,
      'dosis': dosis?.toJson(),
      'mensaje': mensaje,
      'generacion': generacion,
    };
  }

  OperacionIdempotencia toEntity() {
    return OperacionIdempotencia(
      idDosis: idDosis,
      idempotencyKey: idempotencyKey,
      estado: estado,
      confirmado: confirmado,
      enCurso: enCurso,
      rechazado: rechazado,
      dosis: dosis?.toEntity(),
      mensaje: mensaje,
      generacion: generacion,
    );
  }

  factory OperacionIdempotenciaModel.fromEntity(OperacionIdempotencia entity) {
    return OperacionIdempotenciaModel(
      idDosis: entity.idDosis,
      idempotencyKey: entity.idempotencyKey,
      estado: entity.estado,
      confirmado: entity.confirmado,
      enCurso: entity.enCurso,
      rechazado: entity.rechazado,
      dosis: entity.dosis != null ? DosisModel.fromEntity(entity.dosis!) : null,
      mensaje: entity.mensaje,
      generacion: entity.generacion,
    );
  }
}
