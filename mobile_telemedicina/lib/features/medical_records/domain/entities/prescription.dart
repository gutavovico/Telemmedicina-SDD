// Entidades inmutables de CU16 (recetas médicas digitales).
// Alineadas al contrato móvil de prescripciones: el backend solo persiste
// `EMITIDA | ANULADA`; `VIGENTE`/`VENCIDA` son estados visuales derivados.

/// Estado persistido recibido del backend.
///
/// `desconocido` representa cualquier valor no contemplado por el contrato
/// (`EMITIDA | ANULADA`). Existe para no presentar información inválida como
/// "Vigente": el badge mostrará "Desconocido" sin semántica de vigencia.
enum EstadoReceta { emitida, anulada, desconocido }

/// Estado visual derivado para presentación.
enum EstadoVisualReceta { vigente, vencida, anulada, desconocido }

/// Convierte el valor crudo del backend al enum de dominio.
///
/// Tolera minúsculas/mayúsculas y espacios (`emitida`, ` EMITIDA `).
/// Cualquier valor desconocido o vacío se mapea a
/// [EstadoReceta.desconocido] y nunca a `emitida`/`vigente`/`anulada`.
EstadoReceta estadoRecetaFromString(String raw) {
  final normalized = raw.trim().toUpperCase();
  switch (normalized) {
    case 'ANULADA':
      return EstadoReceta.anulada;
    case 'EMITIDA':
      return EstadoReceta.emitida;
    default:
      return EstadoReceta.desconocido;
  }
}

/// Valor canónico para serialización / query params.
String estadoRecetaToString(EstadoReceta estado) {
  switch (estado) {
    case EstadoReceta.anulada:
      return 'ANULADA';
    case EstadoReceta.emitida:
      return 'EMITIDA';
    case EstadoReceta.desconocido:
      return 'DESCONOCIDO';
  }
}

/// Calcula el estado visual según la prioridad del contrato §3:
/// 1. ANULADA si estado == ANULADA.
/// 2. VENCIDA si EMITIDA y estaVencida == true.
/// 3. VIGENTE si EMITIDA y estaVencida == false.
/// 4. DESCONOCIDO si el estado persistido es desconocido (sin vigencia).
EstadoVisualReceta estadoVisualDe({
  required EstadoReceta estado,
  required bool estaVencida,
}) {
  if (estado == EstadoReceta.anulada) return EstadoVisualReceta.anulada;
  if (estado == EstadoReceta.desconocido) {
    return EstadoVisualReceta.desconocido;
  }
  if (estaVencida) return EstadoVisualReceta.vencida;
  return EstadoVisualReceta.vigente;
}

/// Resumen del médico emisor.
class PrescriptionMedico {
  final int idMedico;
  final String nombreCompleto;
  final String matriculaProfesional;
  final String? especialidad;

  const PrescriptionMedico({
    required this.idMedico,
    required this.nombreCompleto,
    required this.matriculaProfesional,
    this.especialidad,
  });
}

/// Resumen del paciente titular.
class PrescriptionPaciente {
  final int idPaciente;
  final String nombreCompleto;

  const PrescriptionPaciente({
    required this.idPaciente,
    required this.nombreCompleto,
  });
}

/// Detalle de medicamento con posología.
class PrescriptionDetalle {
  final int idRecetaDetalle;
  final int? idMedicamento;
  final String? nombreMedicamentoManual;
  final String medicamentoNombre;
  final String? principioActivo;
  final String? concentracion;
  final String? formaFarmaceutica;
  final String dosis;
  final String frecuencia;
  final String duracion;
  final String viaAdministracion;
  final int cantidad;
  final String? indicaciones;
  final int posicion;

  const PrescriptionDetalle({
    required this.idRecetaDetalle,
    this.idMedicamento,
    this.nombreMedicamentoManual,
    required this.medicamentoNombre,
    this.principioActivo,
    this.concentracion,
    this.formaFarmaceutica,
    required this.dosis,
    required this.frecuencia,
    required this.duracion,
    required this.viaAdministracion,
    required this.cantidad,
    this.indicaciones,
    required this.posicion,
  });
}

/// Receta médica digital completa.
///
/// `detalles` se almacena como lista no modificable con copia defensiva:
/// ningún consumidor puede mutar el estado interno mediante
/// `prescription.detalles.add(...)` o `prescription.detalles.clear()`.
class Prescription {
  final int idReceta;
  final int idClinica;
  final int idConsulta;
  final int idPaciente;
  final int idMedico;
  final int? idDocumento;
  final int? idRecetaSustituta;
  final String folio;
  final String pdfUrl;
  final String? indicacionesGenerales;
  final String algoritmoFirma;
  final String keyId;
  final int versionPayload;
  final String hashPdf;
  final String fechaEmision;
  final String fechaVencimiento;
  final bool estaVencida;
  final EstadoReceta estado;
  final String? motivoAnulacion;
  final String? observacionesAnulacion;
  final String? fechaAnulacion;
  final PrescriptionMedico medico;
  final PrescriptionPaciente paciente;
  final List<PrescriptionDetalle> detalles;

  Prescription({
    required this.idReceta,
    required this.idClinica,
    required this.idConsulta,
    required this.idPaciente,
    required this.idMedico,
    this.idDocumento,
    this.idRecetaSustituta,
    required this.folio,
    required this.pdfUrl,
    this.indicacionesGenerales,
    required this.algoritmoFirma,
    required this.keyId,
    required this.versionPayload,
    required this.hashPdf,
    required this.fechaEmision,
    required this.fechaVencimiento,
    required this.estaVencida,
    required this.estado,
    this.motivoAnulacion,
    this.observacionesAnulacion,
    this.fechaAnulacion,
    required this.medico,
    required this.paciente,
    required List<PrescriptionDetalle> detalles,
  }) : detalles = List<PrescriptionDetalle>.unmodifiable(detalles);

  /// Estado visual derivado (nunca `VENCIDA` persistida).
  EstadoVisualReceta get estadoVisual =>
      estadoVisualDe(estado: estado, estaVencida: estaVencida);

  bool get estaAnulada => estado == EstadoReceta.anulada;

  /// Medicamentos ordenados ascendentemente por `posicion`.
  List<PrescriptionDetalle> get detallesOrdenados {
    final sorted = List<PrescriptionDetalle>.from(detalles);
    sorted.sort((a, b) => a.posicion.compareTo(b.posicion));
    return List<PrescriptionDetalle>.unmodifiable(sorted);
  }
}

/// Resultado paginado con paginación `skip/limit` del backend.
///
/// El backend solo devuelve `items` y `total`; el cliente deriva:
/// `page = floor(skip / limit) + 1` y `hasMore = skip + items.length < total`.
///
/// `items` se almacena como lista no modificable con copia defensiva.
class PrescriptionPage {
  final List<Prescription> items;
  final int total;
  final int skip;
  final int limit;

  PrescriptionPage({
    required List<Prescription> items,
    required this.total,
    required this.skip,
    required this.limit,
  }) : items = List<Prescription>.unmodifiable(items);

  /// Página 1-indexada derivada.
  int get page {
    if (limit <= 0) return 1;
    return (skip ~/ limit) + 1;
  }

  /// Indica si quedan elementos por cargar.
  bool get hasMore => skip + items.length < total;

  static bool calcHasMore({
    required int skip,
    required int limit,
    required int itemsLength,
    required int total,
  }) {
    return skip + itemsLength < total;
  }
}

/// Nombre de archivo seguro derivado del folio.
/// Nunca usa rutas del servidor; solo caracteres alfanuméricos, `-` y `_`.
String prescriptionPdfFilename(String folio) {
  final sanitized = folio.replaceAll(RegExp(r'[^A-Za-z0-9\-_]+'), '_');
  final trimmed = sanitized.replaceAll(RegExp(r'_+'), '_');
  final base = trimmed.isEmpty ? 'receta' : trimmed;
  return 'receta_$base.pdf';
}
