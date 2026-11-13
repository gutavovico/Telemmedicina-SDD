import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/core/config/api_config.dart';
import 'package:mobile_telemedicina/core/network/api_client_interface.dart';
import 'package:mobile_telemedicina/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mobile_telemedicina/features/auth/data/models/auth_models.dart';
import 'package:mobile_telemedicina/features/auth/domain/services/inactivity_service.dart';

/// Cliente HTTP falso: registra las llamadas POST para poder afirmar sobre la
/// URL y el cuerpo enviados.
class FakeApiClient implements ApiClientInterface {
  final List<String> postUrls = [];
  final List<Map<String, dynamic>> postBodies = [];

  @override
  Future<dynamic> post(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    postUrls.add(url);
    postBodies.add(Map<String, dynamic>.from(body as Map));
    return null;
  }

  @override
  Future<dynamic> get(String url, {bool includeAuth = true, String? authToken, Map<String, String>? headers}) async {
    return <String, dynamic>{
      'activa': true,
      'segundos_restantes': 900,
      'ventana_segundos': 900,
      'aviso_segundos': 60,
    };
  }

  @override
  Future<dynamic> patch(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async => null;

  @override
  Future<dynamic> delete(
    String url, {
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async => null;

  @override
  Future<Uint8List> downloadBytes(String url, {bool includeAuth = true}) async {
    throw UnimplementedError();
  }
}

/// Pruebas del cierre de sesion global (CU24) en el movil.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthRemoteDataSource.logout (CU24)', () {
    test('envia el refresh_token al endpoint de logout', () async {
      final client = FakeApiClient();
      final datasource = AuthRemoteDataSource(apiClient: client);

      await datasource.logout('refresh-abc');

      expect(client.postUrls, [ApiConfig.logoutUrl]);
      expect(client.postBodies.single['refresh_token'], 'refresh-abc');
    });

    test('el cierre por inactividad NO notifica un logout global', () {
      // Un logout incrementaria `token_version` y cerraria las sesiones del
      // usuario en otros dispositivos, que no es lo que ocurre al vencer la
      // ventana de inactividad: esa sesion ya la revoco el backend por `jti`.
      final client = FakeApiClient();
      final datasource = AuthRemoteDataSource(apiClient: client);
      final expirado = Completer<void>();

      FakeAsync().run((f) {
        final service = InactivityService(
          remoteDataSource: datasource,
          fetchStatus: () async => SessionStatusResponse(
            segundosRestantes: 15 * 60,
            ventanaSegundos: 15 * 60,
            avisoSegundos: 60,
          ),
          renewSession: () async => SessionStatusResponse(
            segundosRestantes: 15 * 60,
            ventanaSegundos: 15 * 60,
            avisoSegundos: 60,
          ),
          clearSession: () async {},
        );

        service.expired.listen((_) {
          if (!expirado.isCompleted) expirado.complete();
        });

        service.start();
        f.elapse(const Duration(minutes: 15));

        expect(expirado.isCompleted, isTrue);
        expect(client.postUrls, isEmpty);
        service.dispose();
      });
    });
  });
}
