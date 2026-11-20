/// Causas de fallo al consultar o descargar resultados de laboratorio (CU11).
enum LabResultFailureKind {
  sessionExpired,
  forbidden,
  downloadForbidden,
  noClinic,
  noPatientProfile,
  notFound,
  fileNotFound,
  network,
  timeout,
  server,
  emptyFile,
  unknown,
}

/// Error de dominio con un mensaje listo para mostrar al usuario (en español).
class LabResultFailure implements Exception {
  final LabResultFailureKind kind;
  final String message;
  final int? statusCode;

  const LabResultFailure({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => message;
}
