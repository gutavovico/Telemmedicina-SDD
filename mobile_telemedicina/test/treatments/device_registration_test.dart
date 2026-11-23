import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/core/network/api_client_interface.dart';
import 'package:mobile_telemedicina/core/network/api_exceptions.dart';
import 'package:mobile_telemedicina/features/treatments/data/services/device_registration_service.dart';

class DeviceFakeApiClient implements ApiClientInterface {
  final List<Map<String, dynamic>> recordedCalls = [];
  dynamic Function(String url, {dynamic body, Map<String, String>? headers})? onPost;
  dynamic Function(String url, {Map<String, String>? headers})? onDelete;

  @override
  Future<dynamic> post(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    recordedCalls.add({
      'method': 'POST',
      'url': url,
      'body': body,
      'headers': headers,
    });
    if (onPost != null) {
      return onPost!(url, body: body, headers: headers);
    }
    return {'id_dispositivo': 10, 'plataforma': 'ANDROID'};
  }

  @override
  Future<dynamic> delete(
    String url, {
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    recordedCalls.add({
      'method': 'DELETE',
      'url': url,
      'headers': headers,
    });
    if (onDelete != null) {
      return onDelete!(url, headers: headers);
    }
    return {};
  }

  @override
  Future<dynamic> get(
    String url, {
    bool includeAuth = true,
    String? authToken,
    Map<String, String>? headers,
  }) async {
    return {};
  }

  @override
  Future<dynamic> patch(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    return {};
  }

  @override
  Future<Uint8List> downloadBytes(String url, {bool includeAuth = true}) async {
    return Uint8List(0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeviceFakeApiClient fakeApi;
  late DeviceRegistrationService deviceService;

  setUp(() {
    fakeApi = DeviceFakeApiClient();
    deviceService = DeviceRegistrationService(apiClient: fakeApi);
  });

  group('Registro de dispositivo push', () {
    test('registra exitosamente un token FCM con plataforma ANDROID', () async {
      fakeApi.onPost = (url, {body, headers}) {
        expect(url, contains('/api/v1/tratamientos/dispositivos'));
        expect(body['token'], equals('fcm-valid-device-token-12345'));
        expect(body['plataforma'], equals('ANDROID'));
        return {
          'id_dispositivo': 42,
          'plataforma': 'ANDROID',
        };
      };

      final result = await deviceService.registrarDispositivo(
        'fcm-valid-device-token-12345',
        plataforma: 'ANDROID',
      );

      expect(result.success, isTrue);
      expect(result.idDispositivo, equals(42));
      expect(result.plataforma, equals('ANDROID'));
      expect(result.pushAvailable, isTrue);
      expect(deviceService.isPushAvailable, isTrue);
      expect(deviceService.pushUnavailableReason, isNull);
    });

    test('valida argumentos de entrada (token vacío o plataforma inválida)', () async {
      expect(
        () => deviceService.registrarDispositivo('   '),
        throwsArgumentError,
      );

      expect(
        () => deviceService.registrarDispositivo('token', plataforma: 'WINDOWS'),
        throwsArgumentError,
      );
    });
  });

  group('Manejo semántico de error 503 (TREATMENT_DELIVERY_UNAVAILABLE)', () {
    test('captura 503 sin bloquear el flujo de la aplicación', () async {
      fakeApi.onPost = (url, {body, headers}) {
        throw ApiException(
          message: 'Proveedor push no configurado',
          statusCode: 503,
          details: {
            'detail': 'Proveedor push no configurado',
            'code': 'TREATMENT_DELIVERY_UNAVAILABLE',
          },
        );
      };

      // No debe lanzar excepción no controlada
      final result = await deviceService.registrarDispositivo(
        'fcm-token-test-503',
        plataforma: 'ANDROID',
      );

      expect(result.success, isFalse);
      expect(result.pushAvailable, isFalse);
      expect(result.unavailableReason, contains('Proveedor push no configurado'));
      expect(result.errorCode, equals('TREATMENT_DELIVERY_UNAVAILABLE'));

      // El servicio expone el estado de indisponibilidad externa
      expect(deviceService.isPushAvailable, isFalse);
      expect(deviceService.pushUnavailableReason, contains('Proveedor push no configurado'));
    });

    test('captura 503 cuando el código viene en details sin mensaje explícito', () async {
      fakeApi.onPost = (url, {body, headers}) {
        throw ApiException(
          message: 'Error en servicio externo',
          statusCode: 503,
          details: {'code': 'TREATMENT_DELIVERY_UNAVAILABLE'},
        );
      };

      final result = await deviceService.registrarDispositivo('token-503-code');
      expect(result.success, isFalse);
      expect(result.pushAvailable, isFalse);
      expect(result.errorCode, equals('TREATMENT_DELIVERY_UNAVAILABLE'));
      expect(deviceService.isPushAvailable, isFalse);
    });

    test('maneja error 403 (falta de permisos) como error sin romper la app', () async {
      fakeApi.onPost = (url, {body, headers}) {
        throw ForbiddenException('No tiene permisos para registrar dispositivos');
      };

      final result = await deviceService.registrarDispositivo('token-403');
      expect(result.success, isFalse);
      expect(result.pushAvailable, isTrue); // push disponible, solo faltan permisos
      expect(result.errorCode, equals('403'));
      expect(result.unavailableReason, contains('No tiene permisos'));
    });
  });

  group('Revocación de dispositivos push', () {
    test('eliminarDispositivo invoca DELETE en el endpoint correspondiente', () async {
      fakeApi.onDelete = (url, {headers}) {
        expect(url, contains('/api/v1/tratamientos/dispositivos/42'));
        return {};
      };

      final ok = await deviceService.eliminarDispositivo(42);
      expect(ok, isTrue);
      expect(fakeApi.recordedCalls.length, equals(1));
      expect(fakeApi.recordedCalls.first['method'], equals('DELETE'));
    });

    test('trata 404 (NotFoundException) en revocación como éxito idempotente', () async {
      fakeApi.onDelete = (url, {headers}) {
        throw NotFoundException('Dispositivo no encontrado');
      };

      final ok = await deviceService.eliminarDispositivo(999);
      expect(ok, isTrue);
    });

    test('trata 404 (ApiException statusCode 404) como éxito idempotente', () async {
      fakeApi.onDelete = (url, {headers}) {
        throw ApiException(message: 'Not found', statusCode: 404);
      };

      final ok = await deviceService.eliminarDispositivo(999);
      expect(ok, isTrue);
    });

    test('devuelve false ante error de red en revocación', () async {
      fakeApi.onDelete = (url, {headers}) {
        throw NetworkException('Fallo de conexión');
      };

      final ok = await deviceService.eliminarDispositivo(999);
      expect(ok, isFalse);
    });
  });

  group('Políticas de privacidad médica en push', () {
    test('assertNoClinicalData rechaza cualquier información clínica en la carga push', () {
      expect(
        () => DeviceRegistrationService.assertNoClinicalData({
          'token': 'abc',
          'plataforma': 'ANDROID',
          'medicamento': 'Amoxicilina 500mg',
        }),
        throwsArgumentError,
      );

      expect(
        () => DeviceRegistrationService.assertNoClinicalData({
          'token': 'abc',
          'diagnostico': 'Faringitis aguda',
        }),
        throwsArgumentError,
      );

      expect(
        () => DeviceRegistrationService.assertNoClinicalData({
          'token': 'abc',
          'nota': 'Paciente con alergias conocidas',
        }),
        throwsArgumentError,
      );

      expect(
        () => DeviceRegistrationService.assertNoClinicalData({
          'token': 'abc',
          'sintomas': 'Fiebre persistente',
        }),
        throwsArgumentError,
      );

      expect(
        () => DeviceRegistrationService.assertNoClinicalData({
          'token': 'abc',
          'posologia': 'Tomar 1 cada 8h',
        }),
        throwsArgumentError,
      );

      expect(
        () => DeviceRegistrationService.assertNoClinicalData({
          'token': 'abc',
          'extra': {
            'paciente': {'nombre': 'Juan'},
          },
        }),
        throwsArgumentError,
      );

      expect(
        () => DeviceRegistrationService.assertNoClinicalData({
          'token': 'abc',
          'items': [
            {'medicamentos': ['Paracetamol']},
          ],
        }),
        throwsArgumentError,
      );

      // Carga push técnica válida: solo token y plataforma
      expect(
        () => DeviceRegistrationService.assertNoClinicalData({
          'token': 'secure-device-token',
          'plataforma': 'ANDROID',
        }),
        returnsNormally,
      );
    });

    test('registrarDispositivo jamás incluye datos clínicos en el cuerpo de la petición', () async {
      await deviceService.registrarDispositivo('sample-push-token', plataforma: 'IOS');

      expect(fakeApi.recordedCalls.length, equals(1));
      final sentBody = fakeApi.recordedCalls.first['body'] as Map<String, dynamic>;
      expect(sentBody.keys.toSet(), equals({'token', 'plataforma'}));
      expect(
        () => DeviceRegistrationService.assertNoClinicalData(sentBody),
        returnsNormally,
      );
    });
  });
}
