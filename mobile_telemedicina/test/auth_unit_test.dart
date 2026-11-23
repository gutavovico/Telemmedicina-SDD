import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/core/utils/validators.dart';
import 'package:mobile_telemedicina/features/auth/data/models/auth_models.dart';

void main() {
  group('Validators Test Suite', () {
    test('validateEmail checks standard email formats', () {
      expect(Validators.validateEmail(''), isNotNull);
      expect(Validators.validateEmail('invalid-email'), isNotNull);
      expect(Validators.validateEmail('user@domain'), isNotNull);
      expect(Validators.validateEmail('paciente@hospital.com'), isNull);
      expect(Validators.validateEmail('  paciente@hospital.com  '), isNull);
    });

    test('validateName checks minimum and maximum length', () {
      expect(Validators.validateName(''), isNotNull);
      expect(Validators.validateName('A'), isNotNull);
      expect(Validators.validateName('Juan Carlos'), isNull);
      expect(Validators.validateName('Pérez Gómez'), isNull);
    });

    test('validatePassword checks minimum 6 characters', () {
      expect(Validators.validatePassword(''), isNotNull);
      expect(Validators.validatePassword('12345'), isNotNull);
      expect(Validators.validatePassword('123456'), isNull);
      expect(Validators.validatePassword('ClaveSegura123!'), isNull);
    });

    test('validateConfirmPassword checks password equality', () {
      expect(Validators.validateConfirmPassword('123456', 'abcdef'), isNotNull);
      expect(
        Validators.validateConfirmPassword('Clave123', 'Clave123'),
        isNull,
      );
    });

    test('calculatePasswordStrength evaluates scores properly', () {
      expect(Validators.calculatePasswordStrength(''), 0);
      expect(Validators.calculatePasswordStrength('123456'), 1);
      expect(Validators.calculatePasswordStrength('Clave123'), 2);
      expect(Validators.calculatePasswordStrength('ClaveFuerte123!'), 3);
    });

    test('validatePhone allows null or valid phones', () {
      expect(Validators.validatePhone(null), isNull);
      expect(Validators.validatePhone(''), isNull);
      expect(Validators.validatePhone('123'), isNotNull);
      expect(Validators.validatePhone('+591 70000000'), isNull);
    });
  });

  group('Auth Models Serialization Test Suite', () {
    test('LoginRequest converts to JSON', () {
      final req = LoginRequest(
        correo: ' test@mail.com ',
        password: 'password123',
      );
      final json = req.toJson();
      expect(json['correo'], 'test@mail.com');
      expect(json['password'], 'password123');
    });

    test('RegisterRequest converts to JSON with optional phone', () {
      final req = RegisterRequest(
        nombres: ' Juan ',
        apellidos: ' Perez ',
        correo: ' juan@mail.com ',
        password: 'password123',
        telefono: ' +591 70000000 ',
      );
      final json = req.toJson();
      expect(json['nombres'], 'Juan');
      expect(json['apellidos'], 'Perez');
      expect(json['correo'], 'juan@mail.com');
      expect(json['telefono'], '+591 70000000');
    });

    test('TokenResponse deserializes from JSON', () {
      final json = {
        'access_token': 'test_access_jwt',
        'refresh_token': 'test_refresh_jwt',
        'token_type': 'bearer',
      };
      final token = TokenResponse.fromJson(json);
      expect(token.accessToken, 'test_access_jwt');
      expect(token.refreshToken, 'test_refresh_jwt');
      expect(token.tokenType, 'bearer');
    });

    test('UserModel deserializes and calculates full name', () {
      final json = {
        'id_usuario': 10,
        'nombres': 'Carlos',
        'apellidos': 'Santander',
        'correo': 'carlos@hospital.com',
        'telefono': '70000000',
        'id_rol': 2,
        'rol_nombre': 'paciente',
        'tenant_id': 'clinica-7',
        'estado': true,
      };
      final user = UserModel.fromJson(json);
      expect(user.idUsuario, 10);
      expect(user.nombres, 'Carlos');
      expect(user.nombreCompleto, 'Carlos Santander');
      expect(user.correo, 'carlos@hospital.com');
      expect(user.rolNombre, 'paciente');
      expect(user.isPatient, isTrue);
      expect(user.tenantId, 'clinica-7');
      expect(user.toJson()['tenant_id'], 'clinica-7');
    });

    test('UserModel accepts the string role returned by /auth/me', () {
      final user = UserModel.fromJson({
        'id_usuario': 1,
        'nombres': 'Admin',
        'apellidos': 'Sistema',
        'correo': 'admin@telemedicina.com',
        'id_rol': 1,
        'rol': 'ADMIN',
        'estado': 'activo',
      });

      expect(user.rolNombre, 'ADMIN');
      expect(user.isPatient, isFalse);
    });

    test('UserModel accepts id_clinica as tenant returned by /auth/me', () {
      final user = UserModel.fromJson({
        'id_usuario': 4,
        'nombres': 'Paciente',
        'apellidos': 'Prueba',
        'correo': 'paciente@hospital.com',
        'rol': 'PACIENTE',
        'id_clinica': 9,
      });

      expect(user.isPatient, isTrue);
      expect(user.tenantId, '9');
    });

    test('UserModel conserva la preferencia push desactivada del backend', () {
      final user = UserModel.fromJson({
        'id_usuario': 4,
        'nombres': 'Paciente',
        'apellidos': 'Prueba',
        'correo': 'paciente@hospital.com',
        'rol': 'PACIENTE',
        'id_clinica': 9,
        'notificaciones_push': false,
      });

      expect(user.notificacionesPush, isFalse);
      expect(user.toJson()['notificaciones_push'], isFalse);
    });
  });
}
