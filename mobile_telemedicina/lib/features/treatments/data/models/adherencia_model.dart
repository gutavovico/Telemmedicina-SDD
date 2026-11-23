import '../../domain/entities/treatment_entities.dart';

class AdherenciaModel {
  final int numeradorPuntual;
  final int denominadorProgramado;
  final double? porcentaje;
  final String nivel;
  final String? calculadoEn;

  const AdherenciaModel({
    required this.numeradorPuntual,
    required this.denominadorProgramado,
    this.porcentaje,
    required this.nivel,
    this.calculadoEn,
  });

  factory AdherenciaModel.fromJson(Map<String, dynamic> json) {
    return AdherenciaModel(
      numeradorPuntual: (json['numerador_puntual'] as num?)?.toInt() ?? 0,
      denominadorProgramado:
          (json['denominador_programado'] as num?)?.toInt() ?? 0,
      porcentaje: (json['porcentaje'] as num?)?.toDouble(),
      nivel: (json['nivel'] as String?)?.trim() ?? 'SIN_DATOS',
      calculadoEn: json['calculado_en'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numerador_puntual': numeradorPuntual,
      'denominador_programado': denominadorProgramado,
      'porcentaje': porcentaje,
      'nivel': nivel,
      'calculado_en': calculadoEn,
    };
  }

  Adherencia toEntity() {
    return Adherencia(
      numeradorPuntual: numeradorPuntual,
      denominadorProgramado: denominadorProgramado,
      porcentaje: porcentaje,
      nivel: nivel,
      calculadoEn: calculadoEn,
    );
  }

  factory AdherenciaModel.fromEntity(Adherencia entity) {
    return AdherenciaModel(
      numeradorPuntual: entity.numeradorPuntual,
      denominadorProgramado: entity.denominadorProgramado,
      porcentaje: entity.porcentaje,
      nivel: entity.nivel,
      calculadoEn: entity.calculadoEn,
    );
  }
}
