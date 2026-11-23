import 'dart:async' as async;
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../storage/secure_storage_service.dart';
import 'api_exceptions.dart';
import 'api_client_interface.dart';
import '../config/api_config.dart';

class ApiClient implements ApiClientInterface {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final http.Client _client = http.Client();
  final SecureStorageService _storage = SecureStorageService();
  String? _sessionAccessToken;

  void setSessionAccessToken(String? token) => _sessionAccessToken = token;
  bool get hasSessionAccessToken => _sessionAccessToken?.isNotEmpty ?? false;

  void clearSessionAccessToken() => _sessionAccessToken = null;

  Future<Map<String, String>> _buildHeaders({
    bool includeAuth = true,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = _sessionAccessToken ?? await _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final tenantId = await _storage.getTenantId();
      if (tenantId != null && tenantId.isNotEmpty) {
        headers['X-Tenant-ID'] = tenantId;
      }
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  @override
  Future<dynamic> get(
    String url, {
    bool includeAuth = true,
    String? authToken,
    Map<String, String>? headers,
  }) async {
    try {
      final reqHeaders = await _buildHeaders(
        includeAuth: includeAuth,
        extraHeaders: headers,
      );
      if (authToken != null && authToken.isNotEmpty) {
        reqHeaders['Authorization'] = 'Bearer $authToken';
      }
      final response = await _client
          .get(Uri.parse(url), headers: reqHeaders)
          .timeout(ApiConfig.timeoutDuration);

      return _handleResponse(response);
    } on async.TimeoutException {
      throw TimeoutException();
    } on http.ClientException {
      throw NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException('Error de comunicación: ${e.toString()}');
    }
  }

  @override
  Future<Uint8List> downloadBytes(String url, {bool includeAuth = true}) async {
    try {
      final headers = await _buildHeaders(includeAuth: includeAuth);
      headers['Accept'] = '*/*';
      final response = await _client
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.downloadTimeoutDuration);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }

      dynamic decodedBody;
      try {
        if (response.body.isNotEmpty) {
          decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
        }
      } catch (_) {
        decodedBody = response.body;
      }
      final errorMessage = _extractErrorMessage(
        decodedBody,
        response.statusCode,
      );
      throw ApiException(
        message: errorMessage,
        statusCode: response.statusCode,
      );
    } on async.TimeoutException {
      throw TimeoutException();
    } on http.ClientException {
      throw NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException('Error al descargar archivo: ${e.toString()}');
    }
  }

  @override
  Future<dynamic> post(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    try {
      final resolvedHeaders = await _buildHeaders(
        includeAuth: includeAuth,
        extraHeaders: headers,
      );
      final response = await _client
          .post(
            Uri.parse(url),
            headers: resolvedHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeoutDuration);

      return _handleResponse(response);
    } on async.TimeoutException {
      throw TimeoutException();
    } on http.ClientException {
      throw NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException('Error de comunicación: ${e.toString()}');
    }
  }

  /// Audio autenticado. MultipartRequest fija el boundary; no se envía JSON.
  Future<dynamic> postAudio(String url, Uint8List bytes, {
    required String filename, required String mimeType,
  }) async {
    try {
      final headers = await _buildHeaders();
      headers.remove('Content-Type');
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers.addAll(headers)
        ..files.add(http.MultipartFile.fromBytes('audio', bytes,
          filename: filename, contentType: MediaType.parse(mimeType)));
      final streamed = await _client.send(request)
          .timeout(ApiConfig.reportTranscriptionTimeoutDuration);
      final response = await http.Response.fromStream(streamed)
          .timeout(ApiConfig.reportTranscriptionTimeoutDuration);
      return _handleResponse(response);
    } on async.TimeoutException {
      throw TimeoutException();
    } on http.ClientException {
      throw NetworkException();
    } catch (error) {
      if (error is ApiException) rethrow;
      throw NetworkException('No se pudo transcribir el audio.');
    }
  }

  /// Respuesta binaria autenticada; los errores HTTP conservan la semántica JSON.
  Future<http.Response> postBinary(String url, {required Object body}) async {
    try {
      final headers = await _buildHeaders();
      headers['Accept'] = '*/*';
      final response = await _client.post(Uri.parse(url), headers: headers,
        body: jsonEncode(body)).timeout(ApiConfig.reportExportTimeoutDuration);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _handleResponse(response);
      }
      return response;
    } on async.TimeoutException {
      throw TimeoutException();
    } on http.ClientException {
      throw NetworkException();
    } catch (error) {
      if (error is ApiException) rethrow;
      throw NetworkException('Error al descargar archivo: $error');
    }
  }

  @override
  Future<dynamic> patch(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    try {
      final resolvedHeaders = await _buildHeaders(
        includeAuth: includeAuth,
        extraHeaders: headers,
      );
      final response = await _client
          .patch(
            Uri.parse(url),
            headers: resolvedHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeoutDuration);

      return _handleResponse(response);
    } on async.TimeoutException {
      throw TimeoutException();
    } on http.ClientException {
      throw NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException('Error de comunicación: ${e.toString()}');
    }
  }

  Future<dynamic> put(
    String url, {
    dynamic body,
    bool includeAuth = true,
  }) async {
    try {
      final headers = await _buildHeaders(includeAuth: includeAuth);
      final response = await _client
          .put(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeoutDuration);

      return _handleResponse(response);
    } on async.TimeoutException {
      throw TimeoutException();
    } on http.ClientException {
      throw NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException('Error de comunicación: ${e.toString()}');
    }
  }

  @override
  Future<dynamic> delete(
    String url, {
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    try {
      final resolvedHeaders = await _buildHeaders(
        includeAuth: includeAuth,
        extraHeaders: headers,
      );
      final response = await _client
          .delete(Uri.parse(url), headers: resolvedHeaders)
          .timeout(ApiConfig.timeoutDuration);

      return _handleResponse(response);
    } on async.TimeoutException {
      throw TimeoutException();
    } on http.ClientException {
      throw NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException('Error de comunicación: ${e.toString()}');
    }
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decodedBody;
    try {
      if (response.body.isNotEmpty) {
        decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (_) {
      decodedBody = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    final errorMessage = _extractErrorMessage(decodedBody, response.statusCode);

    switch (response.statusCode) {
      case 400:
        throw ApiException(
          message: errorMessage,
          statusCode: 400,
          details: decodedBody,
        );
      case 401:
        throw UnauthorizedException(errorMessage);
      case 403:
        throw ForbiddenException(errorMessage);
      case 404:
        throw NotFoundException(errorMessage);
      case 409:
        throw ConflictException(errorMessage);
      case 422:
        throw ValidationException(errorMessage, details: decodedBody);
      case 500:
      case 502:
      case 503:
        throw ServerException(errorMessage);
      default:
        throw ApiException(
          message: errorMessage,
          statusCode: response.statusCode,
          details: decodedBody,
        );
    }
  }

  String _extractErrorMessage(dynamic body, int statusCode) {
    if (body is Map<String, dynamic>) {
      if (body.containsKey('detail')) {
        final detail = body['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first.containsKey('msg')) {
            return first['msg'].toString();
          }
          return detail.toString();
        }
      }
      if (body.containsKey('message')) {
        return body['message'].toString();
      }
    }
    return 'Error del servidor (Código $statusCode)';
  }
}
