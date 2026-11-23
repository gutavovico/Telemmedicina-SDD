/// Modelo de documento clínico (CU12) alineado a `DocumentoClinicoResponse`
/// y `DocumentoClinicoPaginationResponse` de `openspec/contracts/clinical-documents.md`.
class ClinicalDocumentModel {
  final int idDocumento;
  final int idClinica;
  final int idPaciente;
  final int? idCita;
  final String tipoDocumento;
  final String titulo;
  final String? descripcion;
  final String archivoUrl;
  final String hashArchivo;
  final int? firmadoPor;
  final String fechaDocumento;
  final Map<String, dynamic>? metadatos;
  final String estado;
  final String? createdAt;
  final String? updatedAt;
  final String? pacienteNombre;
  final String? firmanteNombre;

  ClinicalDocumentModel({
    required this.idDocumento,
    required this.idClinica,
    required this.idPaciente,
    this.idCita,
    required this.tipoDocumento,
    required this.titulo,
    this.descripcion,
    required this.archivoUrl,
    required this.hashArchivo,
    this.firmadoPor,
    required this.fechaDocumento,
    this.metadatos,
    required this.estado,
    this.createdAt,
    this.updatedAt,
    this.pacienteNombre,
    this.firmanteNombre,
  });

  factory ClinicalDocumentModel.fromJson(Map<String, dynamic> json) {
    return ClinicalDocumentModel(
      idDocumento: json['id_documento'] as int,
      idClinica: json['id_clinica'] as int,
      idPaciente: json['id_paciente'] as int,
      idCita: json['id_cita'] as int?,
      tipoDocumento: json['tipo_documento'] as String? ?? '',
      titulo: json['titulo'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      archivoUrl: json['archivo_url'] as String? ?? '',
      hashArchivo: json['hash_archivo'] as String? ?? '',
      firmadoPor: json['firmado_por'] as int?,
      fechaDocumento: json['fecha_documento'] as String? ?? '',
      metadatos: json['metadatos'] as Map<String, dynamic>?,
      estado: json['estado'] as String? ?? 'ACTIVO',
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      pacienteNombre: json['paciente_nombre'] as String?,
      firmanteNombre: json['firmante_nombre'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_documento': idDocumento,
      'id_clinica': idClinica,
      'id_paciente': idPaciente,
      'id_cita': idCita,
      'tipo_documento': tipoDocumento,
      'titulo': titulo,
      'descripcion': descripcion,
      'archivo_url': archivoUrl,
      'hash_archivo': hashArchivo,
      'firmado_por': firmadoPor,
      'fecha_documento': fechaDocumento,
      'metadatos': metadatos,
      'estado': estado,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'paciente_nombre': pacienteNombre,
      'firmante_nombre': firmanteNombre,
    };
  }
}

class DocumentoPaginadoModel {
  final List<ClinicalDocumentModel> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  DocumentoPaginadoModel({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory DocumentoPaginadoModel.fromJson(Map<String, dynamic> json) {
    return DocumentoPaginadoModel(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => ClinicalDocumentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 10,
      totalPages: json['total_pages'] as int? ?? 0,
    );
  }
}

class DocumentoDownloadModel {
  final int idDocumento;
  final String urlFirmada;
  final int expiraEn;
  final String nombreArchivo;
  final String contentType;

  DocumentoDownloadModel({
    required this.idDocumento,
    required this.urlFirmada,
    required this.expiraEn,
    required this.nombreArchivo,
    required this.contentType,
  });

  factory DocumentoDownloadModel.fromJson(Map<String, dynamic> json) {
    return DocumentoDownloadModel(
      idDocumento: json['id_documento'] as int,
      urlFirmada: json['url_firmada'] as String? ?? '',
      expiraEn: json['expira_en'] as int? ?? 0,
      nombreArchivo: json['nombre_archivo'] as String? ?? '',
      contentType: json['content_type'] as String? ?? 'application/pdf',
    );
  }
}