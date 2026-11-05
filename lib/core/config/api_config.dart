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

  // Citas y Consultas (Appointments - CU25)
  static String get appointmentsUrl => '$baseUrl/citas';
  static String get availableSlotsUrl => '$baseUrl/citas/horarios-disponibles';

  // Fichas Clínicas (Medical Records - CU09)
  static String get fichasUrl => '$baseUrl/medical-records/fichas';

  // Documentos Clínicos (Medical Records - CU12)
  static String get documentsUrl => '$baseUrl/api/v1/documentos';
  static String get myDocumentsUrl => '$baseUrl/api/v1/documentos/me';
  static String patientDocumentsUrl(int id) => '$baseUrl/api/v1/pacientes/$id/documentos';
  static String documentDetailUrl(int id) => '$baseUrl/api/v1/documentos/$id';
  static String documentDownloadUrl(int id) =>
      '$baseUrl/api/v1/documentos/$id/download';

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
  static String teleconsultaUrl(int idCita) => '$baseUrl/api/v1/citas/$idCita/teleconsulta';
  static String get myTeleconsultaUrl => '$baseUrl/api/v1/citas/me/teleconsulta';
  static String chatMensajesUrl(int idCita) => '$baseUrl/api/v1/citas/$idCita/chat/mensajes';

  // CU22/CU27 reportes; el backend resuelve id_clinica desde la sesión.
  static String get reportCatalogUrl => '$baseUrl/analytics/reportes/catalogo';
  static String get reportOptionsUrl => '$baseUrl/analytics/reportes/opciones';
  static String get reportQueryUrl => '$baseUrl/analytics/reportes/consulta';
  static String get reportExportUrl => '$baseUrl/analytics/reportes/exportar';
  static String get reportInterpretUrl => '$baseUrl/analytics/reportes/interpretar';
  static String get reportTranscribeUrl => '$baseUrl/analytics/reportes/transcribir';
  // Fila virtual y tiempos de espera (CU08)
  static String get liveQueueUrl => '$baseUrl/api/v1/cola';
  static String get miTurnoUrl => '$baseUrl/api/v1/cola/mi-turno';
  static String avanzarColaUrl(int idCita) => '$baseUrl/api/v1/cola/$idCita/avanzar';
  static String perdidaColaUrl(int idCita) => '$baseUrl/api/v1/cola/$idCita/perdida';
  static String get pausasColaUrl => '$baseUrl/api/v1/cola/pausas';

  // Request timeout duration
  static const Duration timeoutDuration = Duration(seconds: 15);
  static const Duration downloadTimeoutDuration = Duration(seconds: 60);
  static const Duration reportExportTimeoutDuration = Duration(seconds: 60);
  static const Duration reportTranscriptionTimeoutDuration = Duration(seconds: 60);

  // Inactivity timeout configuration (CU23)
  static const int inactivityTimeoutMinutes = 15;
  static const int inactivityWarningSeconds = 60;
}
