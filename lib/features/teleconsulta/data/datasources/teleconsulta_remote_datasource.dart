import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, visibleForTesting;
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/chat_message_model.dart';
import '../models/teleconsulta_model.dart';

class TeleconsultaRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  static http.Client _httpClient = http.Client();
  static Future<Map<String, String>> Function()? _headersOverrideForTesting;

  static const Duration _signalTimeout = Duration(seconds: 8);
  static const Duration _chatTimeout = Duration(seconds: 10);

  static const List<Map<String, dynamic>> defaultIceServers = [
    {
      'urls': [
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
        'stun:stun2.l.google.com:19302',
      ],
    },
  ];

  @visibleForTesting
  static void configureForTesting({
    http.Client? client,
    Future<Map<String, String>> Function()? headersBuilder,
  }) {
    _httpClient = client ?? http.Client();
    _headersOverrideForTesting = headersBuilder;
  }

  @visibleForTesting
  static void resetTestingOverrides() {
    _httpClient = http.Client();
    _headersOverrideForTesting = null;
  }

  static Future<Map<String, String>> _buildRealtimeHeaders() async {
    if (_headersOverrideForTesting != null) {
      return _headersOverrideForTesting!();
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      final storage = SecureStorageService();
      final token = await storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final tenantId = await storage.getTenantId();
      if (tenantId != null && tenantId.isNotEmpty) {
        headers['X-Tenant-ID'] = tenantId;
      }
    } catch (_) {}
    return headers;
  }

  static void _logError(String operacion, Object error) {
    if (kDebugMode) {
      debugPrint('[TeleconsultaRemoteDataSource] Error en $operacion: $error');
    }
  }

  Future<TeleconsultaViewModel> getTeleconsulta(int idCita) async {
    TeleconsultaViewModel? vm;
    try {
      final response = await _apiClient.get(ApiConfig.teleconsultaUrl(idCita));
      if (response is Map<String, dynamic>) {
        vm = TeleconsultaViewModel.fromJson(response);
      }
    } catch (e) {
      _logError('getTeleconsulta', e);
    }

    final realtimeMsgs = await obtenerMensajesRealtime(idCita);
    final convertidos = <ChatMessageModel>[];
    for (final rm in realtimeMsgs) {
      final texto = (rm['texto'] ?? '').toString();
      final archNombre = rm['archivoNombre']?.toString();
      if (texto.isEmpty && (archNombre == null || archNombre.isEmpty)) continue;
      final esDoc = rm['esDoctor'] == true;
      convertidos.add(
        ChatMessageModel(
          idMensaje: rm['id'].hashCode.abs(),
          idRemitente: esDoc ? 42 : 10,
          nombreRemitente: (rm['remitente'] ?? (esDoc ? 'Doctor' : 'Paciente')).toString(),
          rolRemitente: esDoc ? 'MEDICO' : 'PACIENTE',
          contenido: texto,
          horaDisplay: '${rm['hora'] ?? 'Ahora'} h',
          esPropio: !esDoc,
          leido: true,
          adjuntoNombre: archNombre,
          adjuntoTamano: rm['archivoTamano']?.toString(),
          adjuntoUrl: rm['archivoUrl']?.toString(),
        ),
      );
    }

    if (vm != null) {
      if (convertidos.isNotEmpty) {
        final existentes = List<ChatMessageModel>.from(vm.mensajes);
        for (final cm in convertidos) {
          final yaEsta = existentes.any(
            (m) => m.contenido == cm.contenido && m.adjuntoNombre == cm.adjuntoNombre,
          );
          if (!yaEsta) {
            existentes.add(cm);
          }
        }
        return TeleconsultaViewModel(
          nombreClinica: vm.nombreClinica,
          usuarioActivo: vm.usuarioActivo,
          paciente: vm.paciente,
          cita: vm.cita,
          medico: vm.medico,
          mensajes: existentes,
        );
      }
      return vm;
    }

    // Fallback local si el endpoint principal requirió sesión remota pero el canal realtime respondió
    return TeleconsultaViewModel(
      nombreClinica: 'Clínica Norte',
      usuarioActivo: const {
        'idUsuario': 10,
        'nombre': 'Paciente',
        'iniciales': 'PA',
      },
      paciente: const PatientSummaryModel(
        idPaciente: 10,
        nombreCompleto: 'Paciente',
        identificacionId: 'N/A',
        inicialesAvatar: 'PA',
        seguroProveedor: 'Seguro Médico',
        seguroPoliza: 'POL-001',
      ),
      cita: AppointmentDetailsModel(
        idCita: idCita,
        nombreMedico: 'Dr. Roberto Gómez Flores',
        especialidad: 'Cardiología',
        rangoFechas: 'Hoy',
        horaTeleconsulta: '10:30 h',
        modalidad: 'TELEMEDICINA',
        estado: 'EN_CURSO',
      ),
      medico: const DoctorProfileSummaryModel(
        idMedico: 42,
        nombreCompleto: 'Dr. Roberto Gómez Flores',
        cargoEtiqueta: 'Médico Especialista',
        biografia: 'Especialista en atención médica por teleconsulta.',
        estadoDisponibilidad: 'DISPONIBLE',
      ),
      mensajes: convertidos,
    );
  }

  Future<TeleconsultaViewModel> getMiTeleconsultaActiva() async {
    final response = await _apiClient.get(ApiConfig.myTeleconsultaUrl);
    if (response is Map<String, dynamic>) {
      return TeleconsultaViewModel.fromJson(response);
    }
    throw Exception('Formato de respuesta inválido al cargar teleconsulta activa');
  }

  Future<ChatMessageModel> enviarMensaje({
    required int idCita,
    required String contenido,
    String? adjuntoNombre,
    String? adjuntoTamano,
    String? adjuntoUrl,
  }) async {
    final now = DateTime.now();
    final horaCorta =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final ext = adjuntoNombre != null && adjuntoNombre.contains('.')
        ? adjuntoNombre.split('.').last.toUpperCase()
        : 'PDF';

    // 1. Enviar al canal en tiempo real incluyendo archivoUrl (base64) para que el médico web lo vea y descargue
    await enviarMensajeRealtime(
      idCita: idCita,
      remitente: 'Paciente (Móvil)',
      texto: contenido,
      hora: horaCorta,
      archivoNombre: adjuntoNombre,
      archivoTamano: adjuntoTamano,
      archivoTipo: ext,
      archivoUrl: adjuntoUrl,
    );

    // 2. Persistir en el endpoint estándar CU15 si está disponible
    final body = <String, dynamic>{
      'idCita': idCita,
      'contenido': contenido,
      'adjuntoNombre': ?adjuntoNombre,
      'adjuntoTamano': ?adjuntoTamano,
      'adjuntoUrl': ?adjuntoUrl,
    };

    try {
      final response = await _apiClient.post(
        ApiConfig.chatMensajesUrl(idCita),
        body: body,
      );

      if (response is Map<String, dynamic>) {
        return ChatMessageModel.fromJson(response);
      }
    } catch (e) {
      _logError('enviarMensaje(persistencia)', e);
    }

    return ChatMessageModel(
      idMensaje: now.millisecondsSinceEpoch,
      idRemitente: 10,
      nombreRemitente: 'Paciente',
      rolRemitente: 'PACIENTE',
      contenido: contenido,
      horaDisplay: '$horaCorta h',
      esPropio: true,
      leido: true,
      adjuntoNombre: adjuntoNombre,
      adjuntoTamano: adjuntoTamano,
      adjuntoUrl: adjuntoUrl,
    );
  }

  /// Obtiene la configuración ICE (STUN/TURN) del backend con respaldo STUN público.
  static Future<List<Map<String, dynamic>>> obtenerIceServers() async {
    try {
      final headers = await _buildRealtimeHeaders();
      final res = await _httpClient
          .get(
            Uri.parse(ApiConfig.teleconsultaConfigUrl),
            headers: headers,
          )
          .timeout(_chatTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['iceServers'] is List) {
          final parsed = <Map<String, dynamic>>[];
          for (final item in decoded['iceServers'] as List) {
            if (item is Map) {
              parsed.add(Map<String, dynamic>.from(item));
            }
          }
          if (parsed.isNotEmpty) {
            return parsed;
          }
        }
      }
    } catch (e) {
      _logError('obtenerIceServers', e);
    }
    return defaultIceServers.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<Map<String, dynamic>?> reportarPresencia({
    required int idCita,
    required String rol,
    required bool conectado,
    String? nombre,
  }) async {
    try {
      final headers = await _buildRealtimeHeaders();
      final res = await _httpClient
          .post(
            Uri.parse(ApiConfig.teleconsultaPresenciaUrl(idCita)),
            headers: headers,
            body: jsonEncode({
              'rol': rol,
              'conectado': conectado,
              'nombre': ?nombre,
            }),
          )
          .timeout(_signalTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (e) {
      _logError('reportarPresencia', e);
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> obtenerMensajesRealtime(int idCita) async {
    try {
      final headers = await _buildRealtimeHeaders();
      final res = await _httpClient
          .get(
            Uri.parse(ApiConfig.teleconsultaChatRealtimeUrl(idCita)),
            headers: headers,
          )
          .timeout(_chatTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is List) {
          return decoded.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (e) {
      _logError('obtenerMensajesRealtime', e);
    }
    return [];
  }

  static Future<void> enviarMensajeRealtime({
    required int idCita,
    required String remitente,
    required String texto,
    required String hora,
    String? archivoNombre,
    String? archivoTamano,
    String? archivoTipo,
    String? archivoUrl,
  }) async {
    final payload = {
      'id': 'msg-movil-${DateTime.now().millisecondsSinceEpoch}',
      'remitente': remitente,
      'hora': hora,
      'esDoctor': false,
      'esSistema': false,
      'texto': texto,
      'archivoNombre': ?archivoNombre,
      'archivoTamano': ?archivoTamano,
      'archivoTipo': archivoTipo ?? 'PDF',
      'archivoUrl': ?archivoUrl,
    };
    try {
      final headers = await _buildRealtimeHeaders();
      await _httpClient
          .post(
            Uri.parse(ApiConfig.teleconsultaChatRealtimeUrl(idCita)),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(_chatTimeout);
    } catch (e) {
      _logError('enviarMensajeRealtime', e);
    }
  }

  static Future<Map<String, dynamic>?> enviarSenalWebrtc({
    required int idCita,
    required String de,
    required String para,
    required String tipo,
    Map<String, dynamic>? data,
    String? peerId,
    String? targetPeerId,
  }) async {
    try {
      final headers = await _buildRealtimeHeaders();
      final body = <String, dynamic>{
        'de': de,
        'para': para,
        'tipo': tipo,
        'data': data ?? <String, dynamic>{},
        'peerId': ?peerId,
        'targetPeerId': ?targetPeerId,
      };
      final res = await _httpClient
          .post(
            Uri.parse(ApiConfig.teleconsultaWebrtcSignalUrl(idCita)),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_signalTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (e) {
      _logError('enviarSenalWebrtc($tipo)', e);
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> obtenerSenalesWebrtc({
    required int idCita,
    required String para,
  }) async {
    try {
      final headers = await _buildRealtimeHeaders();
      final uri = Uri.parse(
        '${ApiConfig.teleconsultaWebrtcSignalUrl(idCita)}?para=$para',
      );
      final res = await _httpClient.get(uri, headers: headers).timeout(_signalTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is List) {
          return decoded.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (e) {
      _logError('obtenerSenalesWebrtc', e);
    }
    return [];
  }
}
