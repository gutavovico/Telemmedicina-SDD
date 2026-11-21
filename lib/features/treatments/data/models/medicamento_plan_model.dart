import '../../domain/entities/treatment_entities.dart';

class MedicamentoPlanModel {
  final int idMedicamentoPlan;
  final int idRecetaDetalle;
  final String medicamentoNombre;
  final String dosis;
  final String viaAdministracion;
  final String? frecuenciaTextoReceta;
  final String? duracionTextoReceta;
  final String? indicaciones;
  final String fechaInicio;
  final String fechaFin;
  final List<String> horasLocales;
  final int? intervaloHoras;
  final String estado;

  const MedicamentoPlanModel({
    required this.idMedicamentoPlan,
    required this.idRecetaDetalle,
    required this.medicamentoNombre,
    required this.dosis,
    required this.viaAdministracion,
    this.frecuenciaTextoReceta,
    this.duracionTextoReceta,
    this.indicaciones,
    required this.fechaInicio,
    required this.fechaFin,
    required this.horasLocales,
    this.intervaloHoras,
    required this.estado,
  });

  factory MedicamentoPlanModel.fromJson(Map<String, dynamic> json) {
    return MedicamentoPlanModel(
      idMedicamentoPlan:
          (json['id_medicamento_plan'] as num?)?.toInt() ?? 0,
      idRecetaDetalle:
          (json['id_receta_detalle'] as num?)?.toInt() ?? 0,
      medicamentoNombre:
          (json['medicamento_nombre'] as String?)?.trim() ?? '',
      dosis: (json['dosis'] as String?)?.trim() ?? '',
      viaAdministracion:
          (json['via_administracion'] as String?)?.trim() ?? '',
      frecuenciaTextoReceta: json['frecuencia_texto_receta'] as String?,
      duracionTextoReceta: json['duracion_texto_receta'] as String?,
      indicaciones: json['indicaciones'] as String?,
      fechaInicio: (json['fecha_inicio'] as String?)?.trim() ?? '',
      fechaFin: (json['fecha_fin'] as String?)?.trim() ?? '',
      horasLocales: (json['horas_locales'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[],
      intervaloHoras: (json['intervalo_horas'] as num?)?.toInt(),
      estado: (json['estado'] as String?)?.trim() ?? 'ACTIVO',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_medicamento_plan': idMedicamentoPlan,
      'id_receta_detalle': idRecetaDetalle,
      'medicamento_nombre': medicamentoNombre,
      'dosis': dosis,
      'via_administracion': viaAdministracion,
      'frecuencia_texto_receta': frecuenciaTextoReceta,
      'duracion_texto_receta': duracionTextoReceta,
      'indicaciones': indicaciones,
      'fecha_inicio': fechaInicio,
      'fecha_fin': fechaFin,
      'horas_locales': horasLocales,
      'intervalo_horas': intervaloHoras,
      'estado': estado,
    };
  }

  MedicamentoPlan toEntity() {
    return MedicamentoPlan(
      idMedicamentoPlan: idMedicamentoPlan,
      idRecetaDetalle: idRecetaDetalle,
      medicamentoNombre: medicamentoNombre,
      dosis: dosis,
      viaAdministracion: viaAdministracion,
      frecuenciaTextoReceta: frecuenciaTextoReceta,
      duracionTextoReceta: duracionTextoReceta,
      indicaciones: indicaciones,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      horasLocales: horasLocales,
      intervaloHoras: intervaloHoras,
      estado: estado,
    );
  }

  factory MedicamentoPlanModel.fromEntity(MedicamentoPlan entity) {
    return MedicamentoPlanModel(
      idMedicamentoPlan: entity.idMedicamentoPlan,
      idRecetaDetalle: entity.idRecetaDetalle,
      medicamentoNombre: entity.medicamentoNombre,
      dosis: entity.dosis,
      viaAdministracion: entity.viaAdministracion,
      frecuenciaTextoReceta: entity.frecuenciaTextoReceta,
      duracionTextoReceta: entity.duracionTextoReceta,
      indicaciones: entity.indicaciones,
      fechaInicio: entity.fechaInicio,
      fechaFin: entity.fechaFin,
      horasLocales: entity.horasLocales,
      intervaloHoras: entity.intervaloHoras,
      estado: entity.estado,
    );
  }
}
