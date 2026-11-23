import '../../domain/entities/laboratory_result.dart';

/// Modelo de resultado de laboratorio (CU11) alineado EXACTAMENTE con
/// `ResultadoLaboratorio` / `ResultadoLaboratorioListResponse` de
/// `openspec/contracts/resultados-laboratorio.md`.
///
/// Tolera campos ausentes u ocultos por permiso (`observaciones`, `hash_archivo`,
/// `datos_correspondencia` pueden no venir o venir `null`) sin romper el parseo.
class LaboratoryResultModel {
  final int idResultado;
  final int? idClinica;
  final String estado;
  final String origen;
  final int? idPaciente;
  final String? pacienteNombre;
  final int? idOrden;
  final int? idExamen;
  final String codigoExamen;
  final String? nombreExamen;
  final String laboratorioOrigen;
  final String fechaRealizacion;
  final String? observaciones;
  final String nombreArchivo;
  final String contentType;
  final int tamanoBytes;
  final String? hashArchivo;
  final int? idDocumento;
  final int? idFuente;
  final String? fuenteCodigo;
  final String? idExterno;
  final int? idSincronizacion;
  final String? motivoPendiente;
  final Map<String, dynamic>? datosCorrespondencia;
  final int? registradoPor;
  final String? registradoPorNombre;
  final String? proceso;
  final String? registradoEn;
  final int? resueltoPor;
  final String? resueltoEn;
  final String? motivoResolucion;

  const LaboratoryResultModel({
    required this.idResultado,
    this.idClinica,
    required this.estado,
    required this.origen,
    this.idPaciente,
    this.pacienteNombre,
    this.idOrden,
    this.idExamen,
    required this.codigoExamen,
    this.nombreExamen,
    required this.laboratorioOrigen,
    required this.fechaRealizacion,
    this.observaciones,
    required this.nombreArchivo,
    required this.contentType,
    required this.tamanoBytes,
    this.hashArchivo,
    this.idDocumento,
    this.idFuente,
    this.fuenteCodigo,
    this.idExterno,
    this.idSincronizacion,
    this.motivoPendiente,
    this.datosCorrespondencia,
    this.registradoPor,
    this.registradoPorNombre,
    this.proceso,
    this.registradoEn,
    this.resueltoPor,
    this.resueltoEn,
    this.motivoResolucion,
  });

  static int? _int(dynamic value) => value is num ? value.toInt() : null;
  static String? _string(dynamic value) => value is String ? value : null;

  factory LaboratoryResultModel.fromJson(Map<String, dynamic> json) {
    final correspondencia = json['datos_correspondencia'];
    return LaboratoryResultModel(
      idResultado: _int(json['id_resultado']) ?? 0,
      idClinica: _int(json['id_clinica']),
      estado: _string(json['estado']) ?? '',
      origen: _string(json['origen']) ?? 'MANUAL',
      idPaciente: _int(json['id_paciente']),
      pacienteNombre: _string(json['paciente_nombre']),
      idOrden: _int(json['id_orden']),
      idExamen: _int(json['id_examen']),
      codigoExamen: _string(json['codigo_examen']) ?? '',
      nombreExamen: _string(json['nombre_examen']),
      laboratorioOrigen: _string(json['laboratorio_origen']) ?? '',
      fechaRealizacion: _string(json['fecha_realizacion']) ?? '',
      observaciones: _string(json['observaciones']),
      nombreArchivo: _string(json['nombre_archivo']) ?? '',
      contentType: _string(json['content_type']) ?? '',
      tamanoBytes: _int(json['tamano_bytes']) ?? 0,
      hashArchivo: _string(json['hash_archivo']),
      idDocumento: _int(json['id_documento']),
      idFuente: _int(json['id_fuente']),
      fuenteCodigo: _string(json['fuente_codigo']),
      idExterno: _string(json['id_externo']),
      idSincronizacion: _int(json['id_sincronizacion']),
      motivoPendiente: _string(json['motivo_pendiente']),
      datosCorrespondencia:
          correspondencia is Map<String, dynamic> ? correspondencia : null,
      registradoPor: _int(json['registrado_por']),
      registradoPorNombre: _string(json['registrado_por_nombre']),
      proceso: _string(json['proceso']),
      registradoEn: _string(json['registrado_en']),
      resueltoPor: _int(json['resuelto_por']),
      resueltoEn: _string(json['resuelto_en']),
      motivoResolucion: _string(json['motivo_resolucion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_resultado': idResultado,
      'id_clinica': idClinica,
      'estado': estado,
      'origen': origen,
      'id_paciente': idPaciente,
      'paciente_nombre': pacienteNombre,
      'id_orden': idOrden,
      'id_examen': idExamen,
      'codigo_examen': codigoExamen,
      'nombre_examen': nombreExamen,
      'laboratorio_origen': laboratorioOrigen,
      'fecha_realizacion': fechaRealizacion,
      'observaciones': observaciones,
      'nombre_archivo': nombreArchivo,
      'content_type': contentType,
      'tamano_bytes': tamanoBytes,
      'hash_archivo': hashArchivo,
      'id_documento': idDocumento,
      'id_fuente': idFuente,
      'fuente_codigo': fuenteCodigo,
      'id_externo': idExterno,
      'id_sincronizacion': idSincronizacion,
      'motivo_pendiente': motivoPendiente,
      'datos_correspondencia': datosCorrespondencia,
      'registrado_por': registradoPor,
      'registrado_por_nombre': registradoPorNombre,
      'proceso': proceso,
      'registrado_en': registradoEn,
      'resuelto_por': resueltoPor,
      'resuelto_en': resueltoEn,
      'motivo_resolucion': motivoResolucion,
    };
  }

  LaboratoryResult toEntity() {
    return LaboratoryResult(
      idResultado: idResultado,
      estado: labResultStatusFromString(estado),
      origen: origen,
      codigoExamen: codigoExamen,
      nombreExamen: nombreExamen,
      laboratorioOrigen: laboratorioOrigen,
      fechaRealizacion: fechaRealizacion,
      nombreArchivo: nombreArchivo,
      contentType: contentType,
      tamanoBytes: tamanoBytes,
      idOrden: idOrden,
      pacienteNombre: pacienteNombre,
      observaciones: observaciones,
      registradoEn: registradoEn,
    );
  }
}

class LaboratoryResultPageModel {
  final List<LaboratoryResultModel> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const LaboratoryResultPageModel({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory LaboratoryResultPageModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return LaboratoryResultPageModel(
      items: (rawItems is List ? rawItems : const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(LaboratoryResultModel.fromJson)
          .toList(),
      total: LaboratoryResultModel._int(json['total']) ?? 0,
      page: LaboratoryResultModel._int(json['page']) ?? 1,
      pageSize: LaboratoryResultModel._int(json['page_size']) ?? 10,
      totalPages: LaboratoryResultModel._int(json['total_pages']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
        'page': page,
        'page_size': pageSize,
        'total_pages': totalPages,
      };

  LaboratoryResultPage toEntity() => LaboratoryResultPage(
        items: items.map((e) => e.toEntity()).toList(),
        total: total,
        page: page,
        pageSize: pageSize,
        totalPages: totalPages,
      );
}
