## Purpose
Proveer autenticación segura mediante tokens JWT/OAuth2 con claims de inquilino (tenant_id), gestión de sesiones con versionado de tokens (CU01, CU24), y recuperación de contraseñas mediante códigos temporales de 6 dígitos basados en HMAC-SHA256 con control de tasa y respuestas genéricas de seguridad (CU23) para la plataforma SaaS Multitenant.

## ADDED Requirements

### Requirement: Autenticación de Usuarios y Emisión de Tokens JWT (CU01)
The system SHALL validar las credenciales de los usuarios en el contexto de su inquilino y emitir un par de tokens criptográficos (access token y refresh token) que incorporen el claim `tenant_id` y `token_version`.

#### Scenario: Inicio de sesión exitoso con credenciales válidas
- **GIVEN** que existe un usuario registrado y activo con correo "admin@telemedicina.com" y contraseña válida "admin123" asociado al tenant "11111111-1111-1111-1111-111111111111"
- **WHEN** el usuario envía una solicitud `POST /api/v1/auth/login` con:
  ```json
  {
    "correo": "admin@telemedicina.com",
    "password": "admin123"
  }
  ```
- **THEN** el sistema responde con código HTTP `200 OK`
- **AND** el cuerpo de la respuesta contiene `access_token`, `refresh_token` y `token_type` "bearer"
- **AND** el `access_token` decodificado contiene los claims `sub`, `email`, `token_version` y `tenant_id` correspondiente a su organización

#### Scenario: Intento de inicio de sesión con contraseña incorrecta
- **GIVEN** que existe un usuario activo con correo "admin@telemedicina.com"
- **WHEN** envía una solicitud `POST /api/v1/auth/login` con contraseña incorrecta "claveErronea456"
- **THEN** el sistema rechaza la autenticación con código HTTP `401 Unauthorized`
- **AND** el mensaje de detalle indica "Correo o contraseña incorrectos"
- **AND** el encabezado `WWW-Authenticate` contiene "Bearer"

#### Scenario: Intento de inicio de sesión con cuenta inactiva o suspendida
- **GIVEN** que existe un usuario con correo "inactivo@telemedicina.com" y contraseña correcta cuyo estado es "inactivo"
- **WHEN** envía una solicitud `POST /api/v1/auth/login`
- **THEN** el sistema responde con código HTTP `403 Forbidden`
- **AND** el mensaje de detalle indica "La cuenta de usuario está inactiva o suspendida"

#### Scenario: Intento de inicio de sesión con campos obligatorios vacíos o malformados
- **WHEN** el cliente envía una solicitud `POST /api/v1/auth/login` con correo vacío o formato de correo no válido
- **THEN** el sistema rechaza la solicitud con código HTTP `422 Unprocessable Entity`
- **AND** no se emite ningún token de acceso

### Requirement: Renovación de Tokens de Acceso (Refresh Token)
The system SHALL permitir la renovación de un token de acceso expirado utilizando un token de actualización (refresh token) válido, verificando que la versión del token coincida con el estado actual del usuario.

#### Scenario: Renovación exitosa de token
- **GIVEN** que el usuario posee un `refresh_token` válido con `token_version` idéntica a la registrada en la base de datos
- **WHEN** envía una solicitud `POST /api/v1/auth/refresh` con dicho token
- **THEN** el sistema responde con código HTTP `200 OK`
- **AND** retorna un nuevo `access_token` y un nuevo `refresh_token`

#### Scenario: Intento de renovación con refresh token revocado o versión desactualizada
- **GIVEN** que el usuario ha cerrado sesión o cambiado contraseña, incrementando su `token_version`
- **WHEN** intenta enviar un `refresh_token` previo con versión obsoleta a `POST /api/v1/auth/refresh`
- **THEN** el sistema responde con código HTTP `401 Unauthorized`
- **AND** el mensaje indica "Sesión cerrada o refresh token revocado"

### Requirement: Cierre de Sesión Seguro y Revocación de Tokens (CU24)
The system SHALL revocar inmediatamente la sesión del usuario al solicitar el cierre de sesión, invalidando la validez de los tokens emitidos mediante el incremento de su versión de sesión (`token_version`).

#### Scenario: Cierre de sesión manual exitoso
- **GIVEN** que el usuario tiene una sesión activa autenticada y posee un `refresh_token`
- **WHEN** envía una solicitud `POST /api/v1/auth/logout` con su `refresh_token`
- **THEN** el sistema responde con código HTTP `204 No Content`
- **AND** la versión de sesión `token_version` del usuario en la base de datos se incrementa en 1
- **AND** cualquier intento posterior de usar el token previo o refrescar la sesión resulta en código HTTP `401 Unauthorized`

### Requirement: Recuperación de Acceso mediante Código Temporal (CU23)
The system SHALL proveer un mecanismo seguro de restablecimiento de contraseña mediante códigos numéricos de 6 dígitos generados criptográficamente con HMAC-SHA256 con caducidad de 30 minutos, limitación de tasa de 5 intentos y respuesta genérica.

#### Scenario: Solicitud de código de recuperación con correo registrado
- **GIVEN** que existe un usuario activo con correo "admin@telemedicina.com"
- **WHEN** envía una solicitud `POST /api/v1/auth/forgot-password` con `{ "correo": "admin@telemedicina.com" }`
- **THEN** el sistema responde con código HTTP `200 OK`
- **AND** el cuerpo de la respuesta contiene la confirmación genérica "Si el correo está registrado, recibirás un código de recuperación."
- **AND** se genera un código de 6 dígitos asociado a una ventana de 30 minutos

#### Scenario: Solicitud de código con correo no registrado (Anti-Enumeration)
- **GIVEN** que el correo "noexiste@externo.com" no está registrado en el sistema
- **WHEN** envía una solicitud `POST /api/v1/auth/forgot-password` con dicho correo
- **THEN** el sistema responde con código HTTP `200 OK`
- **AND** el mensaje es idéntico: "Si el correo está registrado, recibirás un código de recuperación."
- **AND** no se filtra información sobre la existencia de la cuenta

#### Scenario: Restablecimiento exitoso de contraseña con código válido
- **GIVEN** que se emitió un código de recuperación válido para "admin@telemedicina.com" hace menos de 30 minutos
- **WHEN** envía una solicitud `POST /api/v1/auth/reset-password` con:
  ```json
  {
    "correo": "admin@telemedicina.com",
    "codigo": "123456",
    "nueva_password": "nuevaAdmin123"
  }
  ```
- **THEN** el sistema responde con código HTTP `200 OK`
- **AND** el mensaje indica "Contraseña restablecida exitosamente."
- **AND** el hash de la contraseña en la base de datos se actualiza con el nuevo valor
- **AND** el usuario puede iniciar sesión de inmediato con "nuevaAdmin123"

#### Scenario: Bloqueo por exceso de intentos fallidos en recuperación de contraseña (Rate Limiting)
- **GIVEN** que un usuario ingresa códigos erróneos sucesivamente para un correo
- **WHEN** acumula 5 intentos fallidos de validación de código
- **THEN** el sistema bloquea temporalmente los intentos para dicho usuario durante 15 minutos
- **AND** toda solicitud subsecuente responde con código HTTP `429 Too Many Requests`
- **AND** el mensaje detalla "Demasiados intentos fallidos. Intenta de nuevo en X min."
