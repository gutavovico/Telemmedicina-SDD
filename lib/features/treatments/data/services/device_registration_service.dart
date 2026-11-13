import 'dart:async';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_client_interface.dart';
import '../../../../core/network/api_exceptions.dart';

/// Resultado del registro de un dispositivo push (CU17).
class DeviceRegistrationResult {
  final bool success;
  final int? idDispositivo;
  final String? plataforma;
  final bool pushAvailable;
  final String? unavailableReason;
  final String? errorCode;

  const DeviceRegistrationResult({
    required this.success,
    this.idDispositivo,
    this.plataforma,
    this.pushAvailable = true,
    this.unavailableReason,
    this.errorCode,
  });

  factory DeviceRegistrationResult.success({
    required int idDispositivo,
    required String plataforma,
  }) =>
      DeviceRegistrationResult(
        success: true,
        idDispositivo: idDispositivo,
        plataforma: plataforma,
        pushAvailable: true,
      );

  factory DeviceRegistrationResult.unavailable({
    String reason = 'Proveedor push no configurado',
    String errorCode = 'TREATMENT_DELIVERY_UNAVAILABLE',
  }) =>
      DeviceRegistrationResult(
        success: false,
        pushAvailable: false,
        unavailableReason: reason,
        errorCode: errorCode,
      );

  factory DeviceRegistrationResult.error({
    required String reason,
    String? errorCode,
  }) =>
      DeviceRegistrationResult(
        success: false,
        pushAvailable: true,
        unavailableReason: reason,
        errorCode: errorCode,
      );
}

/// Servicio encargado del registro y revocación de dispositivos push para CU17.
///
/// Implementa estrictamente:
/// 1. Registro seguro (`POST /api/v1/tratamientos/dispositivos`).
/// 2. Tolerancia semántica a 503 (`TREATMENT_DELIVERY_UNAVAILABLE`), evitando
///    bloquear el flujo de la aplicación cuando el backend no tiene FCM configurado.
/// 3. Revocación de dispositivo (`DELETE /api/v1/tratamientos/dispositivos/{id}`).
/// 4. Políticas de privacidad: Garantiza que ninguna función o payload envíe
///    medicamento, diagnóstico ni notas clínicas en la carga push.
class DeviceRegistrationService {
  final ApiClientInterface _apiClient;

  bool _isPushAvailable = true;
  String? _pushUnavailableReason;

  DeviceRegistrationService({ApiClientInterface? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Estado de disponibilidad del servicio push en el backend.
  bool get isPushAvailable => _isPushAvailable;

  /// Causa de indisponibilidad si el proveedor push no está operativo.
  String? get pushUnavailableReason => _pushUnavailableReason;

  /// Claves clínicas prohibidas por directriz de privacidad médica CU17 en push.
  static const Set<String> forbiddenClinicalKeys = {
    'medicamento',
    'medicamento_nombre',
    'medicamentos',
    'diagnostico',
    'diagnosticos',
    'cie10',
    'codigo_cie',
    'nota',
    'notas',
    'receta',
    'farmaco',
    'farmacos',
    'sintomas',
    'patologia',
    'indicaciones',
    'dosis',
    'efectiva_en',
    'paciente',
    'prescripcion',
    'posologia',
  };

  /// Valida que el mapa de datos no contenga información clínica protegida.
  static void assertNoClinicalData(Map<String, dynamic> payload) {
    for (final key in payload.keys) {
      if (forbiddenClinicalKeys.contains(key.toLowerCase())) {
        throw ArgumentError(
          'POLÍTICA DE PRIVACIDAD CU17 VIOLADA: Se detectó dato clínico prohibido en push: "$key".',
        );
      }
      final val = payload[key];
      if (val is Map<String, dynamic>) {
        assertNoClinicalData(val);
      } else if (val is List) {
        for (final item in val) {
          if (item is Map<String, dynamic>) {
            assertNoClinicalData(item);
          }
        }
      }
    }
  }

  /// Registra el token push del dispositivo ante el backend.
  ///
  /// Si el backend responde 503 (`TREATMENT_DELIVERY_UNAVAILABLE`), captura
  /// el error semánticamente, NO bloquea el flujo de la aplicación y expone
  /// [isPushAvailable] = false sin afectar la bandeja de avisos en la app.
  Future<DeviceRegistrationResult> registrarDispositivo(
    String token, {
    String plataforma = 'ANDROID',
  }) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) {
      throw ArgumentError('El token push no puede estar vacío');
    }
    final cleanPlat = plataforma.trim().toUpperCase();
    if (cleanPlat != 'ANDROID' && cleanPlat != 'IOS') {
      throw ArgumentError('Plataforma inválida: debe ser ANDROID o IOS');
    }

    final payload = <String, dynamic>{
      'token': cleanToken,
      'plataforma': cleanPlat,
    };

    // Garantía estricta de privacidad previa a la transmisión
    assertNoClinicalData(payload);

    try {
      final response = await _apiClient.post(
        ApiConfig.treatmentDevicesUrl,
        body: payload,
      );

      _isPushAvailable = true;
      _pushUnavailableReason = null;

      if (response is Map<String, dynamic>) {
        return DeviceRegistrationResult.success(
          idDispositivo: (response['id_dispositivo'] as num).toInt(),
          plataforma: response['plataforma'] as String? ?? cleanPlat,
        );
      }

      return DeviceRegistrationResult.success(
        idDispositivo: 0,
        plataforma: cleanPlat,
      );
    } on ApiException catch (e) {
      // Captura semántica de 503 TREATMENT_DELIVERY_UNAVAILABLE
      final detailsCode = (e.details is Map)
          ? ((e.details as Map)['code'] ?? (e.details as Map)['detail_code'])?.toString()
          : null;
      if (e.statusCode == 503 ||
          detailsCode == 'TREATMENT_DELIVERY_UNAVAILABLE' ||
          e.message.contains('TREATMENT_DELIVERY_UNAVAILABLE') ||
          e.message.contains('Proveedor push no configurado')) {
        _isPushAvailable = false;
        _pushUnavailableReason = e.message;
        return DeviceRegistrationResult.unavailable(
          reason: e.message,
          errorCode: 'TREATMENT_DELIVERY_UNAVAILABLE',
        );
      }
      // Otros errores de API (ej. 403 por falta de rol)
      return DeviceRegistrationResult.error(
        reason: e.message,
        errorCode: e.statusCode?.toString(),
      );
    } catch (e) {
      // Errores de red u otros imprevistos no bloquean la aplicación
      return DeviceRegistrationResult.error(
        reason: e.toString(),
      );
    }
  }

  /// Revoca el registro de un dispositivo push en el backend.
  /// Trata 404 como éxito idempotente (dispositivo ya revocado o inexistente).
  Future<bool> eliminarDispositivo(int idDispositivo) async {
    try {
      await _apiClient.delete(
        ApiConfig.treatmentDeviceDetailUrl(idDispositivo),
      );
      return true;
    } on NotFoundException {
      // Ya revocado o inexistente
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
