import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_telemedicina/core/config/api_config.dart';
import 'package:mobile_telemedicina/features/teleconsulta/data/datasources/teleconsulta_remote_datasource.dart';
import 'package:mobile_telemedicina/features/teleconsulta/data/services/webrtc_movil_service.dart';

void main() {
  tearDown(() {
    TeleconsultaRemoteDataSource.resetTestingOverrides();
  });

  group('TeleconsultaRemoteDataSource - red, JWT y señalización WebRTC', () {
    test('reportarPresencia usa ApiConfig.baseUrl y envía Authorization y X-Tenant-ID', () async {
      late http.Request capturedRequest;

      TeleconsultaRemoteDataSource.configureForTesting(
        headersBuilder: () async => {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer jwt-paciente-123',
          'X-Tenant-ID': '7',
        },
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'id_cita': 14,
              'doctor_conectado': true,
              'paciente_conectado': true,
              'estado': 'EN_CURSO',
            }),
            200,
          );
        }),
      );

      final res = await TeleconsultaRemoteDataSource.reportarPresencia(
        idCita: 14,
        rol: 'PACIENTE',
        conectado: true,
        nombre: 'Juan Pérez',
      );

      expect(
        capturedRequest.url.toString(),
        equals(ApiConfig.teleconsultaPresenciaUrl(14)),
      );
      expect(capturedRequest.headers['Authorization'], 'Bearer jwt-paciente-123');
      expect(capturedRequest.headers['X-Tenant-ID'], '7');

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['rol'], 'PACIENTE');
      expect(body['conectado'], true);
      expect(body['nombre'], 'Juan Pérez');

      expect(res, isNotNull);
      expect(res!['doctor_conectado'], true);
      expect(res['estado'], 'EN_CURSO');
    });

    test('enviarSenalWebrtc envía peerId, targetPeerId y payload SDP/ICE', () async {
      late http.Request capturedRequest;

      TeleconsultaRemoteDataSource.configureForTesting(
        headersBuilder: () async => {'Content-Type': 'application/json'},
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'id': 'sig-99',
              'de': 'PACIENTE',
              'para': 'DOCTOR',
              'tipo': 'ANSWER',
              'peerId': 'PACIENTE-1',
              'targetPeerId': 'DOCTOR-9',
              'timestamp': DateTime.now().toIso8601String(),
            }),
            200,
          );
        }),
      );

      final res = await TeleconsultaRemoteDataSource.enviarSenalWebrtc(
        idCita: 42,
        de: 'PACIENTE',
        para: 'DOCTOR',
        tipo: 'ANSWER',
        peerId: 'PACIENTE-1',
        targetPeerId: 'DOCTOR-9',
        data: {'sdp': 'v=0...', 'type': 'answer'},
      );

      expect(
        capturedRequest.url.toString(),
        equals(ApiConfig.teleconsultaWebrtcSignalUrl(42)),
      );
      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['de'], 'PACIENTE');
      expect(body['para'], 'DOCTOR');
      expect(body['tipo'], 'ANSWER');
      expect(body['peerId'], 'PACIENTE-1');
      expect(body['targetPeerId'], 'DOCTOR-9');
      expect((body['data'] as Map)['type'], 'answer');
      expect(res?['id'], 'sig-99');
    });

    test('obtenerSenalesWebrtc consulta el rol destino y decodifica lista', () async {
      late Uri capturedUri;

      TeleconsultaRemoteDataSource.configureForTesting(
        headersBuilder: () async => {'Accept': 'application/json'},
        client: MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode([
              {
                'id': 'sig-1',
                'de': 'DOCTOR',
                'para': 'PACIENTE',
                'tipo': 'OFFER',
                'peerId': 'DOCTOR-1',
                'data': {'sdp': 'v=0', 'type': 'offer'},
                'timestamp': DateTime.now().toIso8601String(),
              },
            ]),
            200,
          );
        }),
      );

      final senales = await TeleconsultaRemoteDataSource.obtenerSenalesWebrtc(
        idCita: 42,
        para: 'PACIENTE',
      );

      expect(
        capturedUri.toString(),
        equals('${ApiConfig.teleconsultaWebrtcSignalUrl(42)}?para=PACIENTE'),
      );
      expect(senales, hasLength(1));
      expect(senales.first['tipo'], 'OFFER');
    });

    test('obtenerIceServers parsea servidores STUN/TURN del backend', () async {
      TeleconsultaRemoteDataSource.configureForTesting(
        headersBuilder: () async => {'Accept': 'application/json'},
        client: MockClient((request) async {
          expect(request.url.toString(), equals(ApiConfig.teleconsultaConfigUrl));
          return http.Response(
            jsonEncode({
              'iceServers': [
                {'urls': ['stun:stun.l.google.com:19302']},
                {
                  'urls': ['turn:turn.ejemplo.com:3478'],
                  'username': 'user1',
                  'credential': 'pass1',
                },
              ],
            }),
            200,
          );
        }),
      );

      final ice = await TeleconsultaRemoteDataSource.obtenerIceServers();
      expect(ice, hasLength(2));
      expect(ice[1]['username'], 'user1');
      expect(ice[1]['credential'], 'pass1');
    });

    test('obtenerIceServers usa respaldo STUN cuando el servidor falla', () async {
      TeleconsultaRemoteDataSource.configureForTesting(
        headersBuilder: () async => {'Accept': 'application/json'},
        client: MockClient((_) async => http.Response('Internal Error', 500)),
      );

      final ice = await TeleconsultaRemoteDataSource.obtenerIceServers();
      expect(ice, isNotEmpty);
      expect(ice.first['urls'], isNotEmpty);
    });
  });

  group('WebrtcSignalingHelper - reglas de señalización', () {
    test('ignora FINALIZAR_CONSULTA durante ventana de gracia de 2.5s al iniciar', () {
      final inicio = DateTime(2026, 11, 21, 12, 0, 0);
      final unSegundoDespues = inicio.add(const Duration(milliseconds: 1200));

      expect(
        WebrtcSignalingHelper.debeIgnorarFinalizacion(
          inicioSesion: inicio,
          ahora: unSegundoDespues,
          signalTimestampIso: unSegundoDespues.toIso8601String(),
        ),
        isTrue,
      );
    });

    test('ignora FINALIZAR_CONSULTA residual con más de 3.5s de antigüedad', () {
      final inicio = DateTime(2026, 11, 21, 12, 0, 0);
      final ahora = inicio.add(const Duration(seconds: 10));
      final senalVieja = ahora.subtract(const Duration(seconds: 5));

      expect(
        WebrtcSignalingHelper.debeIgnorarFinalizacion(
          inicioSesion: inicio,
          ahora: ahora,
          signalTimestampIso: senalVieja.toIso8601String(),
        ),
        isTrue,
      );
    });

    test('acepta FINALIZAR_CONSULTA legítima tras la ventana de gracia', () {
      final inicio = DateTime(2026, 11, 21, 12, 0, 0);
      final ahora = inicio.add(const Duration(seconds: 15));
      final senalReciente = ahora.subtract(const Duration(milliseconds: 500));

      expect(
        WebrtcSignalingHelper.debeIgnorarFinalizacion(
          inicioSesion: inicio,
          ahora: ahora,
          signalTimestampIso: senalReciente.toIso8601String(),
        ),
        isFalse,
      );
    });

    test('correspondeAMiPeer filtra targetPeerId correctamente', () {
      expect(
        WebrtcSignalingHelper.correspondeAMiPeer(
          miPeerId: 'PACIENTE-1',
          targetPeerId: null,
        ),
        isTrue,
      );
      expect(
        WebrtcSignalingHelper.correspondeAMiPeer(
          miPeerId: 'PACIENTE-1',
          targetPeerId: '',
        ),
        isTrue,
      );
      expect(
        WebrtcSignalingHelper.correspondeAMiPeer(
          miPeerId: 'PACIENTE-1',
          targetPeerId: 'PACIENTE-1',
        ),
        isTrue,
      );
      expect(
        WebrtcSignalingHelper.correspondeAMiPeer(
          miPeerId: 'PACIENTE-1',
          targetPeerId: 'PACIENTE-OTRO',
        ),
        isFalse,
      );
    });

    test('decodificarFrameBase64 decodifica data URLs válidas y rechaza inválidas', () {
      final encoded = base64Encode([1, 2, 3, 4]);
      final bytesConPrefijo = WebrtcSignalingHelper.decodificarFrameBase64(
        'data:image/jpeg;base64,$encoded',
      );
      expect(bytesConPrefijo, equals([1, 2, 3, 4]));

      final bytesPuros = WebrtcSignalingHelper.decodificarFrameBase64(encoded);
      expect(bytesPuros, equals([1, 2, 3, 4]));

      expect(WebrtcSignalingHelper.decodificarFrameBase64(''), isNull);
      expect(WebrtcSignalingHelper.decodificarFrameBase64('%%%no-valido%%%'), isNull);
    });
  });
}
