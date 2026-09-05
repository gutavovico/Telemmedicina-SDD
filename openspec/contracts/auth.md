# Contrato de API REST: Autenticación y Seguridad (CU01, CU23, CU24)

**Versión del Contrato:** 2.0.0 (SaaS Multitenant)  
**Estándar:** OpenAPI 3.1 / RESTful JSON  
**Ruta Base:** `/api/v1/auth`  
**Seguridad Global:** `BearerAuth` (Header `Authorization: Bearer <JWT_ACCESS_TOKEN>`) para endpoints protegidos  
**Encabezado Multitenant:** `X-Tenant-ID: <UUID>`  
**Dominio:** `auth` / `security`  

---

## 1. Convenciones Multitenant

- **Login e Identificación de Inquilino:** En peticiones públicas previas a la obtención del token (`/login`, `/forgot-password`), el cliente puede enviar el encabezado `X-Tenant-ID: <UUID>` para resolver el inquilino específico cuando no se deduzca del subdominio de red.
- **Claims en el Token JWT:** Los tokens de acceso emitidos por `/login` incorporan obligatoriamente el claim `tenant_id: UUID` y la versión de sesión `token_version: int`.
- **Revocación:** El endpoint `/logout` incrementa `token_version` en la base de datos, revocando el token de actualización y los tokens de acceso previos.

---

## 2. Esquemas de Datos (Data Schemas)

### 2.1 `LoginRequest`
```json
{
  "correo": "admin@telemedicina.com",
  "password": "admin123"
}
```
* **Campos Requeridos:** `correo` (email válido), `password` (string no vacío)

---

### 2.2 `TokenResponse`
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

---

### 2.3 `RefreshTokenRequest`
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

---

### 2.4 `ForgotPasswordRequest`
```json
{
  "correo": "admin@telemedicina.com"
}
```

---

### 2.5 `ForgotPasswordResponse`
```json
{
  "detail": "Si el correo está registrado, recibirás un código de recuperación.",
  "debug_code": "123456"
}
```
*Nota: `debug_code` solo se expone en entornos locales/desarrollo.*

---

### 2.6 `ResetPasswordRequest`
```json
{
  "correo": "admin@telemedicina.com",
  "codigo": "123456",
  "nueva_password": "nuevaAdmin123"
}
```
* **Validaciones:** `codigo` debe ser una cadena numérica de exactamente 6 dígitos. `nueva_password` requiere mínimo 8 caracteres con mayúscula y número.

---

### 2.7 `UsuarioResponse` (Perfil de Usuario)
```json
{
  "id_usuario": 1,
  "tenant_id": "11111111-1111-1111-1111-111111111111",
  "id_rol": 1,
  "nombres": "Administrador",
  "apellidos": "General",
  "correo": "admin@telemedicina.com",
  "telefono": "+591 70000001",
  "estado": "activo",
  "notificaciones_push": true,
  "notificaciones_email": true,
  "notificaciones_sms": false,
  "created_at": "2026-08-24T10:00:00Z"
}
```

---

## 3. Endpoints

### 3.1 `POST /api/v1/auth/login`
* **Descripción:** Autentica a un usuario con correo y contraseña, y genera el par de tokens JWT con claim `tenant_id`.
* **Headers:**
  * `X-Tenant-ID: <UUID>` (Opcional si se deriva del subdominio)
* **Request Body:** `LoginRequest`
* **Respuestas:**
  * `200 OK` → `TokenResponse`
  * `401 Unauthorized` → `{"detail": "Correo o contraseña incorrectos"}`
  * `403 Forbidden` → `{"detail": "La cuenta de usuario está inactiva o suspendida"}`
  * `422 Unprocessable Entity` → Formato de payload inválido

---

### 3.2 `POST /api/v1/auth/refresh`
* **Descripción:** Emite un nuevo par de tokens validando que el `refresh_token` no esté revocado ni pertenezca a una versión de sesión anterior.
* **Request Body:** `RefreshTokenRequest`
* **Respuestas:**
  * `200 OK` → `TokenResponse`
  * `401 Unauthorized` → `{"detail": "Sesión cerrada o refresh token revocado"}`

---

### 3.3 `POST /api/v1/auth/logout`
* **Descripción:** Revoca la sesión del usuario incrementando su `token_version`.
* **Headers:**
  * `Authorization: Bearer <token>`
* **Request Body:** `RefreshTokenRequest`
* **Respuestas:**
  * `204 No Content`
  * `401 Unauthorized` → Refresh token inválido

---

### 3.4 `GET /api/v1/auth/me`
* **Descripción:** Devuelve la información del usuario autenticado en sesión.
* **Headers:**
  * `Authorization: Bearer <token>`
  * `X-Tenant-ID: <UUID>`
* **Respuestas:**
  * `200 OK` → `UsuarioResponse`
  * `401 Unauthorized`
  * `404 Not Found`

---

### 3.5 `POST /api/v1/auth/forgot-password`
* **Descripción:** Genera un código HMAC-SHA256 de 6 dígitos válido por 30 minutos. Responde con mensaje genérico preventivo de enumeración de cuentas.
* **Headers:**
  * `X-Tenant-ID: <UUID>` (Opcional)
* **Request Body:** `ForgotPasswordRequest`
* **Respuestas:**
  * `200 OK` → `ForgotPasswordResponse`
  * `422 Unprocessable Entity`

---

### 3.6 `POST /api/v1/auth/reset-password`
* **Descripción:** Valida el código de 6 dígitos dentro de la ventana de 30 minutos y actualiza la contraseña del usuario. Aplica bloqueo por 15 minutos tras 5 intentos fallidos.
* **Request Body:** `ResetPasswordRequest`
* **Respuestas:**
  * `200 OK` → `{"detail": "Contraseña restablecida exitosamente."}`
  * `400 Bad Request` → Datos inconsistentes
  * `401 Unauthorized` → `{"detail": "Código de recuperación inválido o expirado."}`
  * `429 Too Many Requests` → `{"detail": "Demasiados intentos fallidos. Intenta de nuevo en 15 min."}`
  * `422 Unprocessable Entity`
