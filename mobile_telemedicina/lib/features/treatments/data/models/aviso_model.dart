import '../../domain/entities/treatment_entities.dart';

class AvisoModel {
  final int idAviso;
  final int idTratamiento;
  final int? idDosis;
  final String tipo;
  final String canal;
  final String? titulo;
  final String? mensaje;
  final String estado;
  final String? programadaEn;
  final String? enviadaEn;
  final String? leidaEn;

  const AvisoModel({
    required this.idAviso,
    required this.idTratamiento,
    this.idDosis,
    required this.tipo,
    required this.canal,
    this.titulo,
    this.mensaje,
    required this.estado,
    this.programadaEn,
    this.enviadaEn,
    this.leidaEn,
  });

  factory AvisoModel.fromJson(Map<String, dynamic> json) {
    return AvisoModel(
      idAviso: (json['id_aviso'] as num?)?.toInt() ?? 0,
      idTratamiento: (json['id_tratamiento'] as num?)?.toInt() ?? 0,
      idDosis: (json['id_dosis'] as num?)?.toInt(),
      tipo: (json['tipo'] as String?)?.trim() ?? '',
      canal: (json['canal'] as String?)?.trim() ?? 'WEB',
      titulo: json['titulo'] as String?,
      mensaje: json['mensaje'] as String?,
      estado: (json['estado'] as String?)?.trim() ?? 'PENDIENTE',
      programadaEn: json['programada_en'] as String?,
      enviadaEn: json['enviada_en'] as String?,
      leidaEn: json['leida_en'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_aviso': idAviso,
      'id_tratamiento': idTratamiento,
      'id_dosis': idDosis,
      'tipo': tipo,
      'canal': canal,
      'titulo': titulo,
      'mensaje': mensaje,
      'estado': estado,
      'programada_en': programadaEn,
      'enviada_en': enviadaEn,
      'leida_en': leidaEn,
    };
  }

  Aviso toEntity() {
    return Aviso(
      idAviso: idAviso,
      idTratamiento: idTratamiento,
      idDosis: idDosis,
      tipo: tipo,
      canal: canal,
      titulo: titulo,
      mensaje: mensaje,
      estado: estado,
      programadaEn: programadaEn,
      enviadaEn: enviadaEn,
      leidaEn: leidaEn,
    );
  }

  factory AvisoModel.fromEntity(Aviso entity) {
    return AvisoModel(
      idAviso: entity.idAviso,
      idTratamiento: entity.idTratamiento,
      idDosis: entity.idDosis,
      tipo: entity.tipo,
      canal: entity.canal,
      titulo: entity.titulo,
      mensaje: entity.mensaje,
      estado: entity.estado,
      programadaEn: entity.programadaEn,
      enviadaEn: entity.enviadaEn,
      leidaEn: entity.leidaEn,
    );
  }
}

class AvisoListResponse {
  final List<AvisoModel> items;
  final int total;

  const AvisoListResponse({
    required this.items,
    required this.total,
  });

  factory AvisoListResponse.fromJson(Map<String, dynamic> json) {
    return AvisoListResponse(
      items: (json['items'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => AvisoModel.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          <AvisoModel>[],
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
