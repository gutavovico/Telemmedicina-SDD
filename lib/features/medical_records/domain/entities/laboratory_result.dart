/// Estados de un resultado de laboratorio según el contrato de CU11.
enum LabResultStatus { incorporado, pendienteRevision, anulado, desconocido }

LabResultStatus labResultStatusFromString(String? value) {
  switch (value) {
    case 'INCORPORADO':
      return LabResultStatus.incorporado;
    case 'PENDIENTE_REVISION':
      return LabResultStatus.pendienteRevision;
    case 'ANULADO':
      return LabResultStatus.anulado;
    default:
      return LabResultStatus.desconocido;
  }
}

/// Entidad de dominio inmutable de un resultado de laboratorio (CU11, solo lectura).
/// Independiente de la capa de datos (Dart puro).
class LaboratoryResult {
  final int idResultado;
  final LabResultStatus estado;
  final String origen;
  final String codigoExamen;
  final String? nombreExamen;
  final String laboratorioOrigen;
  final String fechaRealizacion;
  final String nombreArchivo;
  final String contentType;
  final int tamanoBytes;
  final int? idOrden;
  final String? pacienteNombre;
  final String? observaciones;
  final String? registradoEn;

  const LaboratoryResult({
    required this.idResultado,
    required this.estado,
    required this.origen,
    required this.codigoExamen,
    this.nombreExamen,
    required this.laboratorioOrigen,
    required this.fechaRealizacion,
    required this.nombreArchivo,
    required this.contentType,
    required this.tamanoBytes,
    this.idOrden,
    this.pacienteNombre,
    this.observaciones,
    this.registradoEn,
  });

  /// Nombre a mostrar del estudio: el del catálogo si existe, si no su código.
  String get estudio => (nombreExamen != null && nombreExamen!.trim().isNotEmpty)
      ? nombreExamen!
      : codigoExamen;
}

class LaboratoryResultPage {
  final List<LaboratoryResult> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const LaboratoryResultPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}
