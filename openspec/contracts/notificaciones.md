# Contrato de API REST: Notificaciones Push / Dispositivos (CU19)

**Versión del Contrato:** 1.0.0 (SaaS Multitenant)  
**Estándar:** OpenAPI 3.1 / RESTful JSON  
**Ruta Base:** `/notificaciones` (plano) y `/api/v1/notificaciones`  
**Seguridad Global:** `BearerAuth` (Header `Authorization: Bearer <JWT_ACCESS_TOKEN>`) para endpoints protegidos  
**Encabezado Multitenant:** `X-Tenant-ID: <UUID>`  
**Dominio:** `analytics` / `notificaciones`  

---

## 1. Convenciones Multitenant y Seguridad

- **Control de Acceso:** Todos los endpoints requieren autenticación JWT válida (`BearerAuth`).
- **Aislamiento por Tenant:** Cada operación filtra por `id_clinica` del usuario autenticado. Un usuario solo puede registrar y revocar dispositivos de su propia clínica.
- **Estado de usuario:** El usuario debe estar `ACTIVO` y tener `notificaciones_push = true` para registrar un dispositivo.
- **Códigos HTTP Semánticos:** `201 Created`, `204 No Content`, `400 Bad Request`, `403 Forbidden`, `404 Not Found`, `503 Service Unavailable`.

---

## 2. Esquemas de Datos (Data Schemas)

### 2.1 `DispositivoCreate`
```json
{
  "token": "fcm_token_abc123...",
  "plataforma": "ANDROID"
}
```
- `token`: string, 1–4096 caracteres, no vacío. Token FCM del dispositivo móvil.
- `plataforma`: `"ANDROID"` o `"IOS"` (default `"ANDROID"`).

---

### 2.2 Respuesta de Registro
```json
{
  "id_dispositivo": 42,
  "plataforma": "ANDROID"
}
```
- `id_dispositivo`: int. Identificador del dispositivo registrado.
- `plataforma`: string. Plataforma del dispositivo.

---

## 3. Endpoints

### 3.1 `POST /dispositivos`
Registrar token FCM del móvil.

**Request:** `DispositivoCreate`  
**Respuesta (201):** `{id_dispositivo, plataforma}`

**Validaciones:**
- Usuario debe estar `ACTIVO` (si no, `403` "Usuario no activo").
- Usuario debe tener `notificaciones_push = true` (si no, `403` "Notificaciones push desactivadas").
- Proveedor push debe estar configurado (`avisos.push_configurado()`) (si no, `503` "Proveedor push no configurado").
- El token se valida como no vacío tras `strip()`.

**Comportamiento:**
- Si el token ya existe para el usuario y clínica, se actualiza (activo = true, plataforma, token_cifrado).
- Si no existe, se crea un nuevo registro.
- El token se cifra con Fernet (clave `CU17_DEVICE_TOKEN_KEY`) antes de guardar en `token_cifrado`.
- El hash del token (`token_hash`) se usa para detectar duplicados.

**Reutiliza:** Tabla `tratamiento_dispositivos` de CU17 (misma tabla, mismo cifrado). No se crean tablas ni migraciones nuevas.

---

### 3.2 `DELETE /dispositivos/{id_dispositivo}`
Revocar (desactivar) un dispositivo registrado.

**Parámetros de ruta:** `id_dispositivo` (int)  
**Respuesta (204):** No Content

**Validaciones:**
- El dispositivo debe pertenecer al usuario autenticado y a su clínica (si no, `404` "Dispositivo no encontrado").

**Comportamiento:**
- Marca `activo = False` en `tratamiento_dispositivos`.
- El móvil llama a este endpoint al cerrar sesión (logout), usando el `id_dispositivo` guardado en `SharedPreferences` (clave `cu19_push_device_id`).

---

## 4. Infraestructura Push (reutilizada de CU17)

El módulo de notificaciones de CU19 **reutiliza** la infraestructura FCM de CU17:

| Componente | Origen | Descripción |
|---|---|---|
| Cuenta de servicio Firebase | `secrets/firebase-service-account.json` | Misma que CU17, proyecto `telemedicina-2de88` |
| Clave Fernet | `CU17_DEVICE_TOKEN_KEY` | Cifra/descifra tokens FCM en `token_cifrado` |
| Tabla de dispositivos | `tratamiento_dispositivos` | Misma tabla de CU17 |
| `avisos.push_configurado()` | `app/modules/medical_records/tratamientos/avisos.py` | Verifica que FCM esté configurado |
| `avisos.descifrar_token()` | `app/modules/medical_records/tratamientos/avisos.py` | Descifra token FCM de la base de datos |
| `avisos.enviar_fcm_mensaje()` | `app/modules/medical_records/tratamientos/avisos.py` | Envía push vía FCM HTTP v1 |

**No se crean tablas ni migraciones nuevas.**

---

## 5. Variables de Entorno

| Variable | Descripción | Ejemplo |
|---|---|---|
| `CU17_FCM_PROJECT_ID` | ID del proyecto Firebase (reutilizado CU17) | `telemedicina-2de88` |
| `CU17_FCM_SERVICE_ACCOUNT_FILE` | Ruta a la cuenta de servicio FCM | `secrets/firebase-service-account.json` |
| `CU17_DEVICE_TOKEN_KEY` | Clave Fernet para cifrar tokens FCM | `...` |

Estas variables están en `.env` (gitignored) y `secrets/` está protegido en `.gitignore`.

---

## 6. Flujo de Registro y Revocación (Móvil)

1. El móvil (APK Android) inicia Firebase y solicita permisos de notificaciones.
2. Obtiene el token FCM vía `FirebaseMessaging.instance.getToken()`.
3. Llama `POST /notificaciones/dispositivos` con `{token, plataforma: "ANDROID"}`.
4. Guarda el `id_dispositivo` devuelto en `SharedPreferences` (clave `cu19_push_device_id`).
5. Al cerrar sesión, llama `DELETE /notificaciones/dispositivos/{id_dispositivo}` y elimina la clave de `SharedPreferences`.
6. Si FCM rota el token, se vuelve a registrar automáticamente (`onTokenRefresh`).

**Web / Flutter web:** No inicializan Firebase ni piden permisos. `PushService` es un stub vacío (no-op).
