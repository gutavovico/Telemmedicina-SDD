# Spec: CU19 Procesar Pagos + Notificaciones Push de Pago Confirmado

**Capability ID:** `cu19-pagos-notificaciones`  
**Estado:** Implementado (codificado y pusheado en rama `Miguel`)  
**Paquete Canónico:** `analytics`  
**Casos de Uso:** CU19 (Procesar Pagos), CU20 (Notificaciones/Recordatorios — push de pago confirmado)  
**Versión:** 1.0.0  

---

## 1. Purpose

El sistema SHALL procesar pagos de servicios médicos (citas y teleconsultas) mediante pasarela Stripe (sandbox o simulado), emitir comprobantes digitales en PDF y enviar notificación push "Pago confirmado" a la APK Android del paciente cuando el pago quede confirmado. El push SHALL NO revertir el pago si el proveedor FCM falla.

---

## 2. Requisitos Funcionales (RFC 2119)

### 2.1 Pagos

**RF-01:** El sistema SHALL exponer endpoints de pagos bajo el prefijo `/pagos` (plano) y `/api/v1/pagos`.

**RF-02:** El sistema SHALL permitir crear una sesión de pago (`POST /checkout`) vinculada a una cita/teleconsulta pendiente, con cuerpo `CheckoutCreate` (`id_cita`, `canal`, `metodo_pago`).

**RF-03:** El sistema SHALL listar citas/teleconsultas pendientes de pago (`GET /pendientes`).

**RF-04:** El sistema SHALL listar el historial de pagos y comprobantes del usuario autenticado (`GET /mis-pagos`).

**RF-05:** El sistema SHALL confirmar pagos mediante webhook de Stripe (`POST /webhook/stripe`), sincronización manual (`POST /{id_pago}/sincronizar`) o pago simulado (`POST /{id_pago}/simular-pago`).

**RF-06:** Al confirmarse el pago, el sistema SHALL:
- Marcar `estado = "PAGADO"` y `fecha_pago`.
- Si la cita está `PENDIENTE`, cambiarla a `CONFIRMADA`.
- Crear el `Comprobante` (número `REC-YYYYMMDD-NNNNNN`, tipo `RECIBO`, estado `EMITIDO`).
- Generar el PDF del comprobante.
- Llamar `notificar_pago_confirmado(db, pago)` tras `db.commit()`.

**RF-07:** El sistema SHALL permitir descargar el comprobante en PDF (`GET /{id_pago}/comprobante/pdf`) y obtener el código QR (`GET /{id_pago}/qr`).

**RF-08:** El sistema SHALL exponer el estado de la pasarela (`GET /estado-pasarela`): `habilitada`, `modo` (`STRIPE_SANDBOX` o `SIMULADO`), `moneda` (`BOB`), `pasarela` (`STRIPE`).

### 2.2 Notificaciones Push / Dispositivos

**RF-09:** El sistema SHALL exponer endpoints de dispositivos bajo `/notificaciones` (plano) y `/api/v1/notificaciones`.

**RF-10:** El sistema SHALL permitir registrar un token FCM del móvil (`POST /dispositivos`) con cuerpo `DispositivoCreate` (`token`, `plataforma`).

**RF-11:** El sistema SHALL permitir revocar un dispositivo (`DELETE /dispositivos/{id_dispositivo}`), respondiendo 204.

**RF-12:** El sistema SHALL reutilizar la tabla `tratamiento_dispositivos` y el cifrado Fernet de CU17 (clave `CU17_DEVICE_TOKEN_KEY`). NO se crean tablas ni migraciones nuevas.

**RF-13:** El sistema SHALL enviar push "Pago confirmado" a cada dispositivo activo del usuario en su clínica, tras confirmarse el pago. El push incluye data `{tipo: "PAGO_CONFIRMADO", id_pago, id_cita, numero_comprobante}`.

**RF-14:** Un fallo del proveedor FCM SHALL NO revertir el pago ya confirmado.

### 2.3 Móvil (Flutter)

**RF-15:** `PushService` SHALL inicializarse solo en `!kIsWeb && android`. En web se usa stub vacío (no-op).

**RF-16:** El móvil SHALL registrar su token FCM en `/notificaciones/dispositivos` tras login exitoso y revocarlo al cerrar sesión.

**RF-17:** El `id_dispositivo` SHALL guardarse en `SharedPreferences` (clave `cu19_push_device_id`) para revocarlo en logout.

**RF-18:** Al tocar una notificación de tipo `PAGO_CONFIRMADO`, el móvil SHALL navegar a `/pagos` mediante `prescriptionNavigatorKey`.

**RF-19:** `AndroidManifest.xml` SHALL declarar `POST_NOTIFICATIONS` y el canal `cu19_pagos` (`Importance.high`).

---

## 3. Requisitos No Funcionales

**RNF-01 (Aislamiento tenant):** Cada endpoint filtra por `id_clinica` del usuario autenticado. Un usuario no puede acceder a pagos ni dispositivos de otro tenant.

**RNF-02 (Autenticación):** Todos los endpoints protegidos requieren `Authorization: Bearer <JWT_ACCESS_TOKEN>` y header `X-Tenant-ID`.

**RNF-03 (Resiliencia push):** `notificar_pago_confirmado` SHALL capturar toda excepción y retornar 0 sin revertir el pago.

**RNF-04 (Web sin Firebase):** Web y Flutter web SHALL NO inicializar Firebase ni pedir permisos de notificaciones.

---

## 4. Modelos de Datos

### 4.1 Tablas reutilizadas (sin DDL)

| Tabla | Columnas clave | Rol |
|---|---|---|
| `pagos` | `id_pago`, `id_usuario`, `id_cita`, `id_clinica`, `monto`, `moneda`, `estado`, `referencia_transaccion`, `qr_token` | Registro de pagos |
| `comprobantes` | `id_comprobante`, `id_pago`, `numero_comprobante`, `tipo_comprobante`, `fecha_emision`, `archivo_url`, `estado` | Comprobante digital |
| `tratamiento_dispositivos` (CU17) | `id_clinica`, `id_usuario`, `token_hash`, `token_cifrado`, `plataforma`, `activo` | Dispositivos para push FCM |

### 4.2 Esquemas de request/response

**`CheckoutCreate`**: `{id_cita: int, canal: "WEB"|"MOVIL", metodo_pago: "TARJETA"|"QR"}`

**`PagoResponse`**: `{id_pago, id_usuario, id_cita?, monto, moneda, metodo_pago?, pasarela?, referencia_transaccion?, fecha_pago?, estado, url_checkout?, expira_en?, created_at?, cita_*, comprobante?}`

**`ComprobanteResponse`**: `{id_comprobante, id_pago, numero_comprobante, tipo_comprobante, fecha_emision?, archivo_url?, estado}`

**`CitaPendientePago`**: `{id_cita, fecha_cita?, hora_inicio?, hora_fin?, medico_nombre?, especialidad_nombre?, tipo_consulta?, estado_cita?, monto, moneda, estado_pago?, id_pago?}`

**`DispositivoCreate`**: `{token: string (1-4096), plataforma: "ANDROID"|"IOS"}`

**Respuesta registro dispositivo**: `{id_dispositivo: int, plataforma: string}`

---

## 5. Variables de Entorno

| Variable | Descripción |
|---|---|
| `STRIPE_SECRET_KEY` | Clave secreta de Stripe |
| `STRIPE_PUBLISHABLE_KEY` | Clave pública de Stripe |
| `STRIPE_WEBHOOK_SECRET` | Secreto del webhook Stripe |
| `PAYMENT_PUBLIC_BASE_URL` | URL pública para retornos y QR |
| `CU17_FCM_PROJECT_ID` | ID del proyecto Firebase (reutilizado CU17) |
| `CU17_FCM_SERVICE_ACCOUNT_FILE` | Ruta a la cuenta de servicio FCM |
| `CU17_DEVICE_TOKEN_KEY` | Clave Fernet para cifrar tokens FCM |

---

## 6. Criterios de Aceptación (Gherkin)

```gherkin
Feature: CU19 Procesar Pagos y Notificación Push de Pago Confirmado

  Background:
    Dado un usuario autenticado como paciente en un tenant activo
    Y el tenant tiene al menos una cita pendiente de pago

  Scenario: Crear checkout y pagar con Stripe
    Cuando el paciente solicita checkout para su cita pendiente
    Entonces se crea una sesión de Stripe Checkout con URL de pago
    Y el pago queda en estado PENDIENTE con comprobante pendiente

  Scenario: Pago simulado en modo demo (sin Stripe)
    Cuando la pasarela Stripe no está configurada
    Y el paciente confirma el pago simulado
    Entonces el pago pasa a estado PAGADO
    Y se emite el comprobante con número REC-YYYYMMDD-NNNNNN
    Y la cita asociada pasa a estado CONFIRMADA

  Scenario: Push de pago confirmado al dispositivo Android
    Cuando el pago pasa a estado PAGADO
    Y el usuario tiene un dispositivo Android registrado con token FCM
    Y el proveedor push está configurado
    Entonces el dispositivo recibe push "Pago confirmado"
    Y el payload incluye tipo=PAGO_CONFIRMADO e id_pago

  Scenario: Fallo de push no revierte el pago
    Cuando el proveedor push falla al enviar
    Entonces el pago permanece en estado PAGADO
    Y el comprobante sigue disponible para descarga

  Scenario: Registro y revocación de dispositivo FCM
    Cuando el móvil registra su token FCM
    Entonces el dispositivo queda activo en tratamiento_dispositivos
    Cuando el usuario cierra sesión
    Entonces el dispositivo se revoca (activo = false)

  Scenario: Web no inicializa Firebase
    Cuando la aplicación se ejecuta en web o Flutter web
    Entonces no se inicializa Firebase
    Y no se piden permisos de notificaciones
```

---

## 7. Endpoints Resumen

### Pagos (CU19)

| Método | Ruta | Respuesta |
|---|---|---|
| GET | `/estado-pasarela` | `{habilitada, modo, moneda, pasarela}` |
| POST | `/checkout` | `CheckoutResponse` (201) |
| GET | `/pendientes` | `CitaPendienteListResponse` |
| GET | `/mis-pagos` | `PagoListResponse` |
| GET | `/retorno` | HTML |
| GET | `/simulado/{qr_token}` | HTML |
| POST | `/simulado/{qr_token}/confirmar` | HTML |
| GET | `/qr/{qr_token}` | Redirect 307 |
| POST | `/webhook/stripe` | — |
| GET | `/{id_pago}` | `PagoResponse` |
| POST | `/{id_pago}/sincronizar` | `PagoResponse` |
| POST | `/{id_pago}/simular-pago` | `PagoResponse` |
| GET | `/{id_pago}/comprobante` | `ComprobanteResponse` |
| GET | `/{id_pago}/comprobante/pdf` | PDF |
| GET | `/{id_pago}/qr` | PNG |

### Notificaciones / Dispositivos (CU19)

| Método | Ruta | Respuesta |
|---|---|---|
| POST | `/dispositivos` | `{id_dispositivo, plataforma}` (201) |
| DELETE | `/dispositivos/{id_dispositivo}` | 204 No Content |

Ambos conjuntos de rutas están registrados en plano y bajo el prefijo `/api/v1` en `app/main.py`.
