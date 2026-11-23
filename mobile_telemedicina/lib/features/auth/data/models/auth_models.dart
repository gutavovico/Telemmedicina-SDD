import '../../domain/entities/user_entity.dart';

class LoginRequest {
  final String correo;
  final String password;

  LoginRequest({required this.correo, required this.password});

  Map<String, dynamic> toJson() => {
    'correo': correo.trim(),
    'password': password,
  };
}

class RegisterRequest {
  final String nombres;
  final String apellidos;
  final String correo;
  final String password;
  final String? telefono;

  RegisterRequest({
    required this.nombres,
    required this.apellidos,
    required this.correo,
    required this.password,
    this.telefono,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'correo': correo.trim(),
      'password': password,
    };
    if (telefono != null && telefono!.trim().isNotEmpty) {
      map['telefono'] = telefono!.trim();
    }
    return map;
  }
}

class TokenResponse {
  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final String? tenantId;

  TokenResponse({
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'bearer',
    this.tenantId,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] ?? json['accessToken'] ?? '',
      refreshToken: json['refresh_token'] ?? json['refreshToken'],
      tokenType: json['token_type'] ?? 'bearer',
      tenantId: json['tenant_id']?.toString(),
    );
  }
}

class UserModel extends UserEntity {
  UserModel({
    required super.idUsuario,
    required super.nombres,
    required super.apellidos,
    required super.correo,
    super.telefono,
    super.idRol,
    super.idClinica,
    super.rolNombre,
    super.tenantId,
    super.notificacionesPush,
    dynamic estado,
  }) : super(
         estado: estado is bool
             ? (estado ? 'activo' : 'inactivo')
             : estado?.toString(),
       );

  String get nombreCompleto => '$nombres $apellidos'.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    String? rolParsed;
    if (json['rol_nombre'] != null) {
      rolParsed = json['rol_nombre']?.toString();
    } else if (json['rol'] != null) {
      if (json['rol'] is Map) {
        rolParsed = (json['rol'] as Map)['nombre']?.toString();
      } else {
        rolParsed = json['rol']?.toString();
      }
    }

    final idClinica = json['id_clinica'] is int
        ? json['id_clinica'] as int
        : int.tryParse(json['id_clinica']?.toString() ?? '');

    return UserModel(
      idUsuario: json['id_usuario'] is int
          ? json['id_usuario']
          : int.tryParse(json['id_usuario']?.toString() ?? '0') ?? 0,
      nombres: json['nombres'] ?? '',
      apellidos: json['apellidos'] ?? '',
      correo: json['correo'] ?? '',
      telefono: json['telefono']?.toString(),
      idRol: json['id_rol'] is int
          ? json['id_rol']
          : int.tryParse(json['id_rol']?.toString() ?? ''),
      idClinica: idClinica,
      rolNombre: rolParsed,
      tenantId: (json['tenant_id'] ?? json['id_clinica'])?.toString(),
      estado: json['estado'],
      notificacionesPush: json['notificaciones_push'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id_usuario': idUsuario,
    'nombres': nombres,
    'apellidos': apellidos,
    'correo': correo,
    'telefono': telefono,
    'id_rol': idRol,
    'id_clinica': idClinica,
    'rol_nombre': rolNombre,
    'tenant_id': tenantId,
    'estado': estado,
    'notificaciones_push': notificacionesPush,
  };
}

class ForgotPasswordRequest {
  final String correo;

  /// Canal de entrega del codigo de recuperacion (CU23): `email` o `sms`.
  final String canal;

  ForgotPasswordRequest({required this.correo, this.canal = 'email'});

  Map<String, dynamic> toJson() => {'correo': correo.trim(), 'canal': canal};
}

/// Estado de inactividad de la sesion actual (CU23).
class SessionStatusResponse {
  final int segundosRestantes;
  final int ventanaSegundos;
  final int avisoSegundos;

  SessionStatusResponse({
    required this.segundosRestantes,
    required this.ventanaSegundos,
    required this.avisoSegundos,
  });

  factory SessionStatusResponse.fromJson(Map<String, dynamic> json) {
    return SessionStatusResponse(
      segundosRestantes: (json['segundos_restantes'] as num?)?.toInt() ?? 0,
      ventanaSegundos: (json['ventana_segundos'] as num?)?.toInt() ?? 0,
      avisoSegundos: (json['aviso_segundos'] as num?)?.toInt() ?? 0,
    );
  }
}

class ResetPasswordRequest {
  final String correo;
  final String codigo;
  final String nuevaPassword;

  ResetPasswordRequest({
    required this.correo,
    required this.codigo,
    required this.nuevaPassword,
  });

  Map<String, dynamic> toJson() => {
    'correo': correo.trim(),
    'codigo': codigo,
    'nueva_password': nuevaPassword,
  };
}

class ForgotPasswordResponse {
  final String detail;
  final String? debugCode;

  ForgotPasswordResponse({required this.detail, this.debugCode});

  factory ForgotPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResponse(
      detail: json['detail'] ?? '',
      debugCode: json['debug_code'] ?? json['debugCode'],
    );
  }
}
