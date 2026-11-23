import '../../../../core/network/api_exceptions.dart' as net;
import '../../domain/failures/lab_result_failure.dart';

/// Operación que originó el error: cambia el significado de algunos códigos
/// (por ejemplo un 404 en `/me` no es lo mismo que un 404 en `/archivo`).
enum LabResultOperation { list, file }

/// Traduce los errores del cliente HTTP a mensajes claros en español.
///
/// Acepta las TRES formas de `detail` del contrato de CU11:
/// - objeto `{"codigo": "...", "mensaje": "..."}` (errores de dominio),
/// - lista de validación de FastAPI `[{"loc": [...], "msg": "..."}]`,
/// - texto plano (401/403).
///
/// Limitación conocida: `ApiClient` conserva el cuerpo completo (`details`) solo en 400, 422 y estados
/// sin tratamiento específico; para 401/403/404 solo conserva el texto (y el objeto de dominio queda en
/// "Error del servidor (Código N)"). Por eso, cuando no hay código disponible, el significado se deduce
/// del estado HTTP y de la operación.
class LabResultErrorMapper {
  static const _prefijoGenerico = 'Error del servidor (Código';

  static LabResultFailure fromError(Object error, {required LabResultOperation operation}) {
    if (error is LabResultFailure) return error;
    if (error is net.ApiException) return fromApiException(error, operation: operation);
    return const LabResultFailure(
      kind: LabResultFailureKind.unknown,
      message: 'Ocurrió un error inesperado. Intenta nuevamente.',
    );
  }

  static LabResultFailure fromApiException(
    net.ApiException error, {
    required LabResultOperation operation,
  }) {
    final status = error.statusCode;
    final detalle = _detalle(error);

    if (error is net.NetworkException || (status == null && error is! net.TimeoutException)) {
      return const LabResultFailure(
        kind: LabResultFailureKind.network,
        message: 'No hay conexión con el servidor. Revisa tu internet e intenta nuevamente.',
      );
    }
    if (error is net.TimeoutException || status == 408) {
      return LabResultFailure(
        kind: LabResultFailureKind.timeout,
        statusCode: 408,
        message: operation == LabResultOperation.file
            ? 'La descarga tardó demasiado o se interrumpió. Intenta nuevamente.'
            : 'El servidor tardó demasiado en responder. Intenta nuevamente.',
      );
    }

    final codigo = detalle.codigo;
    if (codigo != null) {
      final porCodigo = _porCodigo(codigo, status);
      if (porCodigo != null) return porCodigo;
    }

    switch (status) {
      case 401:
        return const LabResultFailure(
          kind: LabResultFailureKind.sessionExpired,
          statusCode: 401,
          message: 'Tu sesión venció. Inicia sesión nuevamente para ver tus resultados.',
        );
      case 403:
        final texto = detalle.mensaje ?? '';
        if (texto.contains('documents:read:lab_results')) {
          return const LabResultFailure(
            kind: LabResultFailureKind.downloadForbidden,
            statusCode: 403,
            message: 'Puedes ver los datos de este resultado, pero tu perfil no tiene permiso para ver ni descargar el archivo.',
          );
        }
        if (texto.toLowerCase().contains('clínica') || texto.toLowerCase().contains('clinica')) {
          return const LabResultFailure(
            kind: LabResultFailureKind.noClinic,
            statusCode: 403,
            message: 'Tu cuenta no está asociada a un centro de salud.',
          );
        }
        return LabResultFailure(
          kind: LabResultFailureKind.forbidden,
          statusCode: 403,
          message: operation == LabResultOperation.file
              ? 'No tienes permiso para ver este archivo.'
              : 'No tienes permiso para consultar resultados de laboratorio.',
        );
      case 404:
        return operation == LabResultOperation.list
            ? const LabResultFailure(
                kind: LabResultFailureKind.noPatientProfile,
                statusCode: 404,
                message: 'Tu cuenta no tiene un perfil de paciente en tu centro de salud, por eso no hay resultados para mostrar.',
              )
            : const LabResultFailure(
                kind: LabResultFailureKind.notFound,
                statusCode: 404,
                message: 'El resultado o su archivo ya no está disponible.',
              );
      default:
        break;
    }

    if (status != null && status >= 500) {
      return LabResultFailure(
        kind: LabResultFailureKind.server,
        statusCode: status,
        message: 'El servidor no pudo completar la solicitud. Intenta más tarde.',
      );
    }
    final texto = detalle.mensaje;
    return LabResultFailure(
      kind: LabResultFailureKind.unknown,
      statusCode: status,
      message: (texto != null && texto.trim().isNotEmpty)
          ? texto
          : 'No se pudo completar la operación. Intenta nuevamente.',
    );
  }

  /// Mensajes por código de dominio del contrato (sección 1.1).
  static LabResultFailure? _porCodigo(String codigo, int? status) {
    switch (codigo) {
      case 'RESULTADO_NO_ENCONTRADO':
        return LabResultFailure(
          kind: LabResultFailureKind.notFound,
          statusCode: status,
          message: 'Este resultado ya no está disponible o no pertenece a tu cuenta.',
        );
      case 'ARCHIVO_NO_ENCONTRADO':
        return LabResultFailure(
          kind: LabResultFailureKind.fileNotFound,
          statusCode: status,
          message: 'El archivo de este resultado no se encuentra disponible en este momento.',
        );
      case 'PACIENTE_NO_ENCONTRADO':
        return LabResultFailure(
          kind: LabResultFailureKind.noPatientProfile,
          statusCode: status,
          message: 'Tu cuenta no tiene un perfil de paciente en tu centro de salud, por eso no hay resultados para mostrar.',
        );
      default:
        return null;
    }
  }

  /// Extrae `codigo` y `mensaje` de las tres formas de `detail`.
  static _Detalle _detalle(net.ApiException error) {
    final cuerpo = error.details;
    if (cuerpo is Map) {
      final detail = cuerpo['detail'];
      if (detail is Map) {
        return _Detalle(
          codigo: detail['codigo']?.toString(),
          mensaje: detail['mensaje']?.toString(),
        );
      }
      if (detail is List) {
        final textos = detail
            .map((e) => e is Map ? e['msg']?.toString() : e?.toString())
            .whereType<String>()
            .toList();
        return _Detalle(mensaje: textos.isEmpty ? null : textos.join('. '));
      }
      if (detail is String) {
        return _Detalle(mensaje: detail);
      }
    }
    if (cuerpo is String && cuerpo.trim().isNotEmpty) {
      return _Detalle(mensaje: cuerpo);
    }
    final texto = error.message;
    if (texto.isNotEmpty && !texto.startsWith(_prefijoGenerico)) {
      return _Detalle(mensaje: texto);
    }
    return const _Detalle();
  }
}

class _Detalle {
  final String? codigo;
  final String? mensaje;
  const _Detalle({this.codigo, this.mensaje});
}
