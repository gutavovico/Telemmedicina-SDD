import '../../domain/entities/treatment_entities.dart';
import 'adherencia_model.dart';
import 'dosis_model.dart';

class CronogramaDiaModel {
  final int idTratamiento;
  final String fecha;
  final String zonaHoraria;
  final List<DosisModel> dosis;
  final AdherenciaModel? adherencia;

  const CronogramaDiaModel({
    required this.idTratamiento,
    required this.fecha,
    required this.zonaHoraria,
    required this.dosis,
    this.adherencia,
  });

  factory CronogramaDiaModel.fromJson(Map<String, dynamic> json) {
    return CronogramaDiaModel(
      idTratamiento: (json['id_tratamiento'] as num?)?.toInt() ?? 0,
      fecha: (json['fecha'] as String?)?.trim() ?? '',
      zonaHoraria: (json['zona_horaria'] as String?)?.trim() ?? '',
      dosis: (json['dosis'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => DosisModel.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          <DosisModel>[],
      adherencia: json['adherencia'] != null && json['adherencia'] is Map
          ? AdherenciaModel.fromJson(
              Map<String, dynamic>.from(json['adherencia'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_tratamiento': idTratamiento,
      'fecha': fecha,
      'zona_horaria': zonaHoraria,
      'dosis': dosis.map((d) => d.toJson()).toList(),
      'adherencia': adherencia?.toJson(),
    };
  }

  CronogramaDia toEntity() {
    return CronogramaDia(
      idTratamiento: idTratamiento,
      fecha: fecha,
      zonaHoraria: zonaHoraria,
      dosis: dosis.map((d) => d.toEntity()).toList(),
      adherencia: adherencia?.toEntity(),
    );
  }

  factory CronogramaDiaModel.fromEntity(CronogramaDia entity) {
    return CronogramaDiaModel(
      idTratamiento: entity.idTratamiento,
      fecha: entity.fecha,
      zonaHoraria: entity.zonaHoraria,
      dosis: entity.dosis.map((d) => DosisModel.fromEntity(d)).toList(),
      adherencia: entity.adherencia != null
          ? AdherenciaModel.fromEntity(entity.adherencia!)
          : null,
    );
  }
}
