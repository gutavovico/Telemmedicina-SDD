/// Entidad de dominio inmutable de un documento clínico (CU12).
/// Independiente de la capa de datos (Dart puro).
class ClinicalDocument {
  final int idDocumento;
  final int idPaciente;
  final String tipoDocumento;
  final String titulo;
  final String? descripcion;
  final String fechaDocumento;
  final String estado;
  final String? pacienteNombre;
  final String? firmanteNombre;

  const ClinicalDocument({
    required this.idDocumento,
    required this.idPaciente,
    required this.tipoDocumento,
    required this.titulo,
    this.descripcion,
    required this.fechaDocumento,
    required this.estado,
    this.pacienteNombre,
    this.firmanteNombre,
  });

  bool get estaActivo => estado == 'ACTIVO';
}

class DocumentoPaginado {
  final List<ClinicalDocument> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const DocumentoPaginado({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });
}

class DocumentoDescargable {
  final int idDocumento;
  final String urlFirmada;
  final int expiraEn;
  final String nombreArchivo;
  final String contentType;

  const DocumentoDescargable({
    required this.idDocumento,
    required this.urlFirmada,
    required this.expiraEn,
    required this.nombreArchivo,
    required this.contentType,
  });
}