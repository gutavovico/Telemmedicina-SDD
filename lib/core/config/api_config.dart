class ApiConfig {
  static const String _defaultBaseUrl =
      'https://backend-telemedicina.onrender.com';
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl.endsWith('/')
          ? _configuredBaseUrl.substring(0, _configuredBaseUrl.length - 1)
          : _configuredBaseUrl;
    }
    return _defaultBaseUrl;
  }

  // Auth endpoints
  static String get loginUrl => '$baseUrl/auth/login';
  static String get logoutUrl => '$baseUrl/auth/logout';
  static String get registerUrl => '$baseUrl/auth/register';
  static String get meUrl => '$baseUrl/auth/me';
  static String get refreshUrl => '$baseUrl/auth/refresh';
  static String get sessionUrl => '$baseUrl/auth/session';
  static String get sessionContinueUrl => '$baseUrl/auth/session/continue';
  static String get forgotPasswordUrl => '$baseUrl/auth/forgot-password';
  static String get resetPasswordUrl => '$baseUrl/auth/reset-password';

  // Pacientes endpoints (CU03)
  static String get patientsUrl => '$baseUrl/api/v1/pacientes';
  static String get myPatientProfileUrl => '$baseUrl/api/v1/pacientes/me';

  // Médicos y Especialidades endpoints (CU04)
  static String get doctorsUrl => '$baseUrl/api/v1/medicos';
  static String get specialtiesUrl => '$baseUrl/api/v1/especialidades';

  // Directorio de especialistas y disponibilidad (CU06)
  static String get specialistsUrl => '$baseUrl/api/v1/especialistas';

  // Citas y Consultas (Appointments - CU25)
  static String get appointmentsUrl => '$baseUrl/citas';
  static String get availableSlotsUrl => '$baseUrl/citas/horarios-disponibles';

  // Fichas Clínicas (Medical Records - CU09)
  static String get fichasUrl => '$baseUrl/medical-records/fichas';

  // Documentos Clínicos (Medical Records - CU12)
  static String get documentsUrl => '$baseUrl/api/v1/documentos';
  static String get myDocumentsUrl => '$baseUrl/api/v1/documentos/me';
  static String patientDocumentsUrl(int id) =>
      '$baseUrl/api/v1/pacientes/$id/documentos';
  static String documentDetailUrl(int id) => '$baseUrl/api/v1/documentos/$id';
  static String documentDownloadUrl(int id) =>
      '$baseUrl/api/v1/documentos/$id/download';
  static String documentFileUrl(int id) => '$baseUrl/api/v1/documentos/$id/file';

  // Recetas Médicas Digitales (Medical Records - CU16, solo lectura paciente)
  static String get prescriptionsUrl => '$baseUrl/api/v1/recetas';
  static String prescriptionDetailUrl(int id) => '$baseUrl/api/v1/recetas/$id';
  static String prescriptionPdfUrl(int id) => '$baseUrl/api/v1/recetas/$id/pdf';

  // Asistencia Inteligente de Tratamiento (CU18)
  static String get assistanceEvaluateUrl => '$baseUrl/api/v1/asistencia-tratamiento/evaluar';
  static String get assistanceHistoryUrl => '$baseUrl/api/v1/asistencia-tratamiento/historial';
  static String assistanceDetailUrl(int id) => '$baseUrl/api/v1/asistencia-tratamiento/evaluaciones/$id';
  static String get assistanceCatalogUrl => '$baseUrl/api/v1/asistencia-tratamiento/interacciones/catalogo';

  // Teleconsulta y Chat de Cita Médica (CU15)
  static String teleconsultaUrl(int idCita) =>
      '$baseUrl/api/v1/citas/$idCita/teleconsulta';
  static String get myTeleconsultaUrl =>
      '$baseUrl/api/v1/citas/me/teleconsulta';
  static String chatMensajesUrl(int idCita) =>
      '$baseUrl/api/v1/citas/$idCita/chat/mensajes';

  // CU22/CU27 reportes; el backend resuelve id_clinica desde la sesión.
  static String get reportCatalogUrl => '$baseUrl/analytics/reportes/catalogo';
  static String get reportOptionsUrl => '$baseUrl/analytics/reportes/opciones';
  static String get reportQueryUrl => '$baseUrl/analytics/reportes/consulta';
  static String get reportExportUrl => '$baseUrl/analytics/reportes/exportar';
  static String get reportInterpretUrl =>
      '$baseUrl/analytics/reportes/interpretar';
  static String get reportTranscribeUrl =>
      '$baseUrl/analytics/reportes/transcribir';
  // Pagos de citas y teleconsultas + comprobantes (CU19)
  static String get paymentsUrl => '$baseUrl/pagos';
  static String get paymentsCheckoutUrl => '$baseUrl/pagos/checkout';
  static String get paymentsPendingUrl => '$baseUrl/pagos/pendientes';
  static String get paymentsMineUrl => '$baseUrl/pagos/mis-pagos';
  static String get paymentsStateUrl => '$baseUrl/pagos/estado-pasarela';
  static String paymentUrl(int idPago) => '$baseUrl/pagos/$idPago';
  static String paymentSyncUrl(int idPago) =>
      '$baseUrl/pagos/$idPago/sincronizar';
  static String paymentSimulateUrl(int idPago) =>
      '$baseUrl/pagos/$idPago/simular-pago';
  static String paymentReceiptUrl(int idPago) =>
      '$baseUrl/pagos/$idPago/comprobante/pdf';

  // Notificaciones push del móvil (CU19)
  static String get pushDevicesUrl => '$baseUrl/notificaciones/dispositivos';
  static String pushDeviceUrl(int id) => '$baseUrl/notificaciones/dispositivos/$id';

  // Fila virtual y tiempos de espera (CU08)
  static String get liveQueueUrl => '$baseUrl/api/v1/cola';
  static String get miTurnoUrl => '$baseUrl/api/v1/cola/mi-turno';
  static String avanzarColaUrl(int idCita) =>
      '$baseUrl/api/v1/cola/$idCita/avanzar';
  static String perdidaColaUrl(int idCita) =>
      '$baseUrl/api/v1/cola/$idCita/perdida';
  static String get pausasColaUrl => '$baseUrl/api/v1/cola/pausas';

  // Tratamientos Médicos (CU17)
  static String get treatmentsUrl => '$baseUrl/api/v1/tratamientos';
  static String treatmentDetailUrl(int id) => '$baseUrl/api/v1/tratamientos/$id';
  static String cronogramaUrl(int id, String fecha) =>
      '$baseUrl/api/v1/tratamientos/$id/cronograma?fecha=$fecha';
  static String adherenciaUrl(int id) =>
      '$baseUrl/api/v1/tratamientos/$id/adherencia';
  static String dosisIntentosUrl(int idDosis) =>
      '$baseUrl/api/v1/tratamientos/dosis/$idDosis/intentos';
  static String dosisRegistrosUrl(int idDosis) =>
      '$baseUrl/api/v1/tratamientos/dosis/$idDosis/registros';
  static String dosisIdempotenciaUrl(int idDosis, String key) =>
      '$baseUrl/api/v1/tratamientos/dosis/$idDosis/registros/idempotencia/$key';
  static String dosisResolverUrl(int idDosis, String key) =>
      '$baseUrl/api/v1/tratamientos/dosis/$idDosis/registros/idempotencia/$key/resolver';
  static String avisosUrl({int skip = 0, int limit = 20, bool noLeidos = false}) =>
      '$baseUrl/api/v1/tratamientos/avisos?skip=$skip&limit=$limit${noLeidos ? '&no_leidos=true' : ''}';
  static String leerAvisoUrl(int idAviso) =>
      '$baseUrl/api/v1/tratamientos/avisos/$idAviso/leer';
  static String get dispositivosUrl =>
      '$baseUrl/api/v1/tratamientos/dispositivos';
  static String dispositivoDetailUrl(int idDispositivo) =>
      '$baseUrl/api/v1/tratamientos/dispositivos/$idDispositivo';

  // Aliases for compatibility
  static String treatmentScheduleUrl(int id, String fecha) => cronogramaUrl(id, fecha);
  static String treatmentAdherenceUrl(int id) => adherenciaUrl(id);
  static String doseAttemptsUrl(int idDosis) => dosisIntentosUrl(idDosis);
  static String doseRecordsUrl(int idDosis) => dosisRegistrosUrl(idDosis);
  static String doseIdempotencyUrl(int idDosis, String idempotencyKey) =>
      dosisIdempotenciaUrl(idDosis, idempotencyKey);
  static String doseResolveUrl(int idDosis, String idempotencyKey) =>
      dosisResolverUrl(idDosis, idempotencyKey);
  static String get treatmentAlertsUrl => '$baseUrl/api/v1/tratamientos/avisos';
  static String treatmentAlertReadUrl(int idAviso) => leerAvisoUrl(idAviso);
  static String get treatmentDevicesUrl => dispositivosUrl;
  static String treatmentDeviceDetailUrl(int idDispositivo) =>
      dispositivoDetailUrl(idDispositivo);

  // Request timeout duration
  static const Duration timeoutDuration = Duration(seconds: 15);
  static const Duration downloadTimeoutDuration = Duration(seconds: 60);
  static const Duration reportExportTimeoutDuration = Duration(seconds: 60);
  static const Duration reportTranscriptionTimeoutDuration = Duration(
    seconds: 60,
  );

  // Inactivity timeout configuration (CU23)
  static const int inactivityTimeoutMinutes = 15;
  static const int inactivityWarningSeconds = 60;
}
