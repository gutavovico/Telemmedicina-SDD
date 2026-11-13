import 'dart:typed_data';

/// Contrato mínimo del cliente HTTP usado por los servicios de datos (CU12, CU17).
/// Permite inyectar fakes en pruebas unitarias.
abstract class ApiClientInterface {
  Future<dynamic> get(
    String url, {
    bool includeAuth = true,
    String? authToken,
    Map<String, String>? headers,
  });

  Future<dynamic> post(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  });

  Future<dynamic> patch(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  });

  Future<dynamic> delete(
    String url, {
    bool includeAuth = true,
    Map<String, String>? headers,
  });

  Future<Uint8List> downloadBytes(String url, {bool includeAuth = true});
}
