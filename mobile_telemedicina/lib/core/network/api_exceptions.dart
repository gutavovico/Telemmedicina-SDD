class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  ApiException({
    required this.message,
    this.statusCode,
    this.details,
  });

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException([String message = 'No se pudo conectar con el servidor. Verifica tu conexión a internet.'])
      : super(message: message, statusCode: null);
}

class TimeoutException extends ApiException {
  TimeoutException([String message = 'Tiempo de espera agotado. El servidor tardó demasiado en responder.'])
      : super(message: message, statusCode: 408);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([String message = 'No autenticado: token inválido o ausente'])
      : super(message: message, statusCode: 401);
}

class ForbiddenException extends ApiException {
  ForbiddenException([String message = 'Acceso restringido: No cuentas con autorización para este recurso en tu centro de salud.'])
      : super(message: message, statusCode: 403);
}

class NotFoundException extends ApiException {
  NotFoundException([String message = 'El recurso solicitado no fue encontrado en este centro de salud.'])
      : super(message: message, statusCode: 404);
}

class ConflictException extends ApiException {
  ConflictException([String message = 'Conflicto: El recurso o turno ya se encuentra reservado u ocupado.'])
      : super(message: message, statusCode: 409);
}

class ValidationException extends ApiException {
  ValidationException(String message, {super.details})
      : super(message: message, statusCode: 422);
}

class ServerException extends ApiException {
  ServerException([String message = 'Error interno en el servidor. Por favor intenta más tarde.'])
      : super(message: message, statusCode: 500);
}
