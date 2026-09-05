---
name: flutter-mobile-standards
description: Estándares de desarrollo para la aplicación móvil en Flutter (Dart). Arquitectura limpia por capas (Data, Domain, Presentation), gestión de estado con Provider / BLoC, modelos serializables alineados con OpenSpec y manejo seguro de tokens y tenant context.
---

# Flutter Mobile Standards - App Móvil Multitenant

Este estándar define los patrones de arquitectura limpia, gestión de estado y consumo de APIs REST para la aplicación móvil multiplataforma desarrollada en **Flutter (Dart)** para pacientes y médicos.

---

## 1. Arquitectura Limpia por Capas (Clean Architecture)

El código móvil se organiza por **Features** (dominios funcionales), y cada feature se estructura en tres capas desacopladas:

```
mobile_telemedicina/
├── lib/
│   ├── core/                          # Infraestructura transversal
│   │   ├── network/                   # Cliente HTTP (Dio/Http), interceptores de Tenant y Auth
│   │   ├── storage/                   # SecureStorage (JWT, tenant_id)
│   │   ├── theme/                     # Tema Material 3, tipografía y paleta
│   │   └── errors/                    # Fallas y excepciones estandarizadas
│   ├── features/                      # Features por dominio
│   │   ├── medical_records/           # Expedientes y perfil de paciente
│   │   │   ├── data/                  # CAPA DE DATOS
│   │   │   │   ├── models/            # paciente_model.dart (serialización JSON Pydantic)
│   │   │   │   ├── datasources/       # paciente_remote_datasource.dart (llamadas HTTP)
│   │   │   │   └── repositories/      # paciente_repository_impl.dart
│   │   │   ├── domain/                # CAPA DE DOMINIO
│   │   │   │   ├── entities/          # paciente_entity.dart (inmutable)
│   │   │   │   ├── repositories/      # paciente_repository.dart (interfaz abstracta)
│   │   │   │   └── usecases/          # get_perfil_paciente_usecase.dart, update_contacto_usecase.dart
│   │   │   └── presentation/          # CAPA DE PRESENTACIÓN
│   │   │       ├── providers/         # paciente_provider.dart (ChangeNotifier / BLoC)
│   │   │       ├── screens/           # paciente_profile_screen.dart, edit_contacto_screen.dart
│   │   │       └── widgets/           # emergency_contact_card.dart, blood_type_badge.dart
│   │   └── auth/                      # Login, selección de clínica/tenant
│   └── main.dart                      # Configuración de Providers y MaterialApp
```

### Reglas de Dependencia entre Capas:
1. **Presentación:** Conoce únicamente a la capa de **Dominio** (mediante casos de uso y entidades).
2. **Dominio:** Es código Dart puro. No depende de paquetes de Flutter, bases de datos ni clientes HTTP. Contiene las reglas de negocio esenciales.
3. **Datos:** Implementa las interfaces del dominio, transforma modelos JSON desde/hacia entidades y maneja excepciones de red.

---

## 2. Gestión de Estado Reactiva (Provider / BLoC)

- Utilizar **Provider** con `ChangeNotifier` (o **BLoC** para flujos complejos) separando claramente los estados de la UI:
  - `InitialState`
  - `LoadingState`
  - `SuccessState<T>`
  - `ErrorState(String message, String? errorCode)`
- **Notificaciones Atómicas:** Evitar re-renderizados innecesarios en la jerarquía de widgets utilizando selectores (`Consumer`, `context.select(...)`).

```dart
// presentation/providers/paciente_provider.dart
class PacienteProvider extends ChangeNotifier {
  final GetPerfilPacienteUseCase getPerfilUseCase;
  final UpdateContactoUseCase updateContactoUseCase;

  PacienteProvider({
    required this.getPerfilUseCase,
    required this.updateContactoUseCase,
  });

  PacienteEntity? _paciente;
  bool _isLoading = false;
  String? _errorMessage;

  PacienteEntity? get paciente => _paciente;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> cargarPerfil() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await getPerfilUseCase();
    result.fold(
      (failure) => _errorMessage = failure.message,
      (data) => _paciente = data,
    );

    _isLoading = false;
    notifyListeners();
  }
}
```

---

## 3. Modelos Serializables Alineados con `openspec/contracts/`

- Los modelos Dart en `data/models/` deben reflejar con exactitud de nombres y tipos los esquemas JSON de Pydantic v2 documentados en `openspec/contracts/*.md`.
- Implementar métodos `fromJson` y `toJson` con manejo explícito de nulos:

```dart
// data/models/paciente_model.dart
class PacienteModel extends PacienteEntity {
  const PacienteModel({
    required super.idPaciente,
    required super.tenantId,
    required super.nombres,
    required super.apellidos,
    required super.ci,
    super.complemento,
    required super.fechaNacimiento,
    required super.genero,
    required super.telefono,
    super.correo,
    super.direccion,
    super.ciudad,
    super.tipoSangre,
    super.contactoEmergenciaNombre,
    super.contactoEmergenciaTelefono,
    super.contactoEmergenciaParentesco,
    required super.estado,
    required super.createdAt,
  });

  factory PacienteModel.fromJson(Map<String, dynamic> json) {
    return PacienteModel(
      idPaciente: json['id_paciente'] as int,
      tenantId: json['tenant_id'] as String,
      nombres: json['nombres'] as String,
      apellidos: json['apellidos'] as String,
      ci: json['ci'] as String,
      complemento: json['complemento'] as String? ?? '',
      fechaNacimiento: DateTime.parse(json['fecha_nacimiento'] as String),
      genero: json['genero'] as String,
      telefono: json['telefono'] as String,
      correo: json['correo'] as String?,
      direccion: json['direccion'] as String?,
      ciudad: json['ciudad'] as String?,
      tipoSangre: json['tipo_sangre'] as String?,
      contactoEmergenciaNombre: json['contacto_emergencia_nombre'] as String?,
      contactoEmergenciaTelefono: json['contacto_emergencia_telefono'] as String?,
      contactoEmergenciaParentesco: json['contacto_emergencia_parentesco'] as String?,
      estado: json['estado'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toPatchProfileJson() {
    return {
      'telefono': telefono,
      'correo': correo,
      'direccion': direccion,
      'ciudad': ciudad,
      'contacto_emergencia_nombre': contactoEmergenciaNombre,
      'contacto_emergencia_telefono': contactoEmergenciaTelefono,
      'contacto_emergencia_parentesco': contactoEmergenciaParentesco,
    };
  }
}
```

---

## 4. Manejo Seguro de Tokens y Contexto Multitenant

1. **Almacenamiento Seguro:**
   - Almacenar el token JWT y el `tenant_id` en `FlutterSecureStorage` con opciones de cifrado de plataforma (KeyStore en Android, Keychain en iOS).
2. **Inyección en Peticiones HTTP:**
   - Todo request autenticado debe inyectar:
     - `Authorization: Bearer <jwt_token>`
     - `X-Tenant-ID: <tenant_id>`
3. **Resiliencia ante 401 / 403:**
   - Si el backend rechaza la sesión con `401 Unauthorized`, limpiar almacenamiento local y redirigir al login.
   - Si el backend responde `404 Not Found` en un recurso de paciente, mostrar feedback claro al usuario indicando que el registro no existe o no pertenece a la organización seleccionada.
