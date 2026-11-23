import '../../domain/entities/treatment_entities.dart';

class DosisModel {
  final int idDosis;
  final int idMedicamentoPlan;
  final String programadaEn;
  final String programadaHoraLocal;
  final String zonaHoraria;
  final String estado;
  final bool vencida;
  final String? efectivaEn;
  final String? registradaEn;
  final bool? puntual;
  final String? nota;

  const DosisModel({
    required this.idDosis,
    required this.idMedicamentoPlan,
    required this.programadaEn,
    required this.programadaHoraLocal,
    required this.zonaHoraria,
    required this.estado,
    required this.vencida,
    this.efectivaEn,
    this.registradaEn,
    this.puntual,
    this.nota,
  });

  factory DosisModel.fromJson(Map<String, dynamic> json) {
    return DosisModel(
      idDosis: (json['id_dosis'] as num?)?.toInt() ?? 0,
      idMedicamentoPlan:
          (json['id_medicamento_plan'] as num?)?.toInt() ?? 0,
      programadaEn: (json['programada_en'] as String?)?.trim() ?? '',
      programadaHoraLocal:
          (json['programada_hora_local'] as String?)?.trim() ?? '',
      zonaHoraria: (json['zona_horaria'] as String?)?.trim() ?? '',
      estado: (json['estado'] as String?)?.trim() ?? 'PENDIENTE',
      vencida: json['vencida'] as bool? ?? false,
      efectivaEn: json['efectiva_en'] as String?,
      registradaEn: json['registrada_en'] as String?,
      puntual: json['puntual'] as bool?,
      nota: json['nota'] as String?,
    );
  }

  bool get esPendiente => estado.toUpperCase() == 'PENDIENTE';
  bool get esIngerida => estado.toUpperCase() == 'INGERIDA';
  bool get esOmitida => estado.toUpperCase() == 'OMITIDA';
  bool get esPospuesta => estado.toUpperCase() == 'POSPUESTA';
  bool get esPuntual => puntual ?? false;

  Map<String, dynamic> toJson() {
    return {
      'id_dosis': idDosis,
      'id_medicamento_plan': idMedicamentoPlan,
      'programada_en': programadaEn,
      'programada_hora_local': programadaHoraLocal,
      'zona_horaria': zonaHoraria,
      'estado': estado,
      'vencida': vencida,
      'efectiva_en': efectivaEn,
      'registrada_en': registradaEn,
      'puntual': puntual,
      'nota': nota,
    };
  }

  Dosis toEntity() {
    return Dosis(
      idDosis: idDosis,
      idMedicamentoPlan: idMedicamentoPlan,
      programadaEn: programadaEn,
      programadaHoraLocal: programadaHoraLocal,
      zonaHoraria: zonaHoraria,
      estado: estado,
      vencida: vencida,
      efectivaEn: efectivaEn,
      registradaEn: registradaEn,
      puntual: puntual,
      nota: nota,
    );
  }

  factory DosisModel.fromEntity(Dosis entity) {
    return DosisModel(
      idDosis: entity.idDosis,
      idMedicamentoPlan: entity.idMedicamentoPlan,
      programadaEn: entity.programadaEn,
      programadaHoraLocal: entity.programadaHoraLocal,
      zonaHoraria: entity.zonaHoraria,
      estado: entity.estado,
      vencida: entity.vencida,
      efectivaEn: entity.efectivaEn,
      registradaEn: entity.registradaEn,
      puntual: entity.puntual,
      nota: entity.nota,
    );
  }
}
