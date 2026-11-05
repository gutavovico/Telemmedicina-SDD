# Propuesta de Cambio: CU19 Procesar Pagos + Notificaciones Push de Pago Confirmado (`cu19-pagos-notificaciones`)

## 1. Contexto y Objetivos

Habilitar el **procesamiento de pagos de servicios médicos** (CU19): el paciente paga en línea una cita o teleconsulta pendiente mediante pasarela Stripe (modo sandbox o simulado), el sistema emite el comprobante digital en PDF y, al confirmarse el pago, envía una notificación push "pago confirmado" a la APK Android.

Los objetivos son:

1. Permitir al paciente crear una sesión de pago (`checkout`) vinculada a una cita/teleconsulta pendiente.
2. Listar citas/teleconsultas pendientes de pago y el historial de pagos del usuario.
3. Confirmar pagos mediante webhook de Stripe, sincronización manual o pago simulado.
4. Emitir el comprobante digital (PDF) al confirmarse el pago.
5. Enviar notificación push "Pago confirmado" al dispositivo Android del paciente tras `db.commit()` del pago.
6. Registrar y revocar tokens FCM de dispositivos móviles para recibir push.
7. Garantizar que un fallo del proveedor push **no revierta** el pago ya confirmado.

CU19 vive en el paquete canónico **analytics** (ver `system-design/spec.md`, matriz de paquetes). Reutiliza la infraestructura FCM de **CU17** (misma cuenta de servicio, mismo cifrado Fernet, misma tabla `tratamiento_dispositivos`) sin crear tablas ni migraciones nuevas.

## 2. Reutilización de Tablas (sin DDL nuevo)

No se crea ninguna tabla ni migración. Columnas ya existentes:

| Tabla | Columnas usadas | Rol en CU19 |
|---|---|---|
| `pagos` | `id_pago`, `id_usuario`, `id_cita`, `id_clinica`, `monto`, `moneda`, `estado`, `referencia_transaccion`, `stripe_session_id`, `stripe_payment_intent_id`, `fecha_pago`, `qr_token` | Registro de pagos y estados |
| `comprobantes` | `id_comprobante`, `id_pago`, `numero_comprobante`, `tipo_comprobante`, `fecha_emision`, `archivo_url`, `estado` | Comprobante digital emitido por pago |
| `tratamiento_dispositivos` (CU17) | `id_clinica`, `id_usuario`, `token_hash`, `token_cifrado`, `plataforma`, `activo` | Dispositivos registrados para push FCM |
| `citas` | `id_cita`, `id_clinica`, `estado` | Cita asociada al pago; se confirma (`CONFIRMADA`) al pagar |
| `usuarios` | `id_usuario`, `id_clinica`, `estado`, `notificaciones_push` | Usuario destinatario del push y aislamiento tenant |

## 3. Alcance por Plataforma

- **Backend (FastAPI):** endpoints de pagos bajo `/pagos` y `/api/v1/pagos`; endpoints de dispositivos push bajo `/notificaciones` y `/api/v1/notificaciones`; hook `notificar_pago_confirmado` tras `db.commit()` en `_finalizar_pago`.
- **Web (Angular):** consumo de endpoints de pagos (checkout, mis pagos, comprobante). No inicializa Firebase ni pide permisos de push.
- **Móvil (Flutter):** consumo de endpoints de pagos + registro de token FCM en `/notificaciones/dispositivos`; canal `cu19_pagos`; navegación a `/pagos` al tocar notificación. Solo en APK Android (`!kIsWeb && android`).

## 4. Endpoints de API

### 4.1 Pagos (CU19)

Prefijo: `/pagos` (plano) y `/api/v1/pagos`. Seguridad: `BearerAuth` + `X-Tenant-ID`.

| Método | Ruta | Resumen | Cuerpo de request | Respuesta |
|---|---|---|---|---|
| GET | `/estado-pasarela` | Estado de la pasarela Stripe | — | `{habilitada, modo, moneda, pasarela}` |
| POST | `/checkout` | Crear sesión de pago | `CheckoutCreate` | `CheckoutResponse` |
| GET | `/pendientes` | Citas pendientes de pago | — | `CitaPendienteListResponse` |
| GET | `/mis-pagos` | Historial de pagos del usuario | — | `PagoListResponse` |
| GET | `/retorno` | Página de retorno del Checkout (móvil) | query `estado`, `pago` | HTML |
| GET | `/simulado/{qr_token}` | Página de pago simulado (demo) | — | HTML |
| POST | `/simulado/{qr_token}/confirmar` | Confirmar pago simulado | — | HTML |
| GET | `/qr/{qr_token}` | Redirección corta del código QR | — | Redirect 307 |
| POST | `/webhook/stripe` | Webhook de confirmación Stripe | payload + `Stripe-Signature` | — |
| GET | `/{id_pago}` | Detalle de un pago | — | `PagoResponse` |
| POST | `/{id_pago}/sincronizar` | Sincronizar estado con Stripe | — | `PagoResponse` |
| POST | `/{id_pago}/simular-pago` | Confirmar pago en modo demo | — | `PagoResponse` |
| GET | `/{id_pago}/comprobante` | Comprobante digital | — | `ComprobanteResponse` |
| GET | `/{id_pago}/comprobante/pdf` | Descargar comprobante PDF | — | PDF (attachment) |
| GET | `/{id_pago}/qr` | Imagen QR PNG para pagar | — | PNG |

### 4.2 Notificaciones / Dispositivos Push (CU19)

Prefijo: `/notificaciones` (plano) y `/api/v1/notificaciones`. Seguridad: `BearerAuth` + `X-Tenant-ID`.

| Método | Ruta | Resumen | Cuerpo de request | Respuesta |
|---|---|---|---|---|
| POST | `/dispositivos` | Registrar token FCM del móvil | `DispositivoCreate` | `{id_dispositivo, plataforma}` |
| DELETE | `/dispositivos/{id_dispositivo}` | Revocar dispositivo | — | 204 No Content |

### 4.3 Esquemas de Datos

**`CheckoutCreate`**
```json
{
  "id_cita": 123,
  "canal": "WEB",
  "metodo_pago": "TARJETA"
}
```
- `id_cita`: int, requerido, > 0
- `canal`: `"WEB"` o `"MOVIL"` (default `"WEB"`)
- `metodo_pago`: `"TARJETA"` o `"QR"` (default `"TARJETA"`)

**`PagoResponse`**
```json
{
  "id_pago": 1,
  "id_usuario": 15,
  "id_cita": 123,
  "monto": 150.00,
  "moneda": "BOB",
  "metodo_pago": "TARJETA",
  "pasarela": "STRIPE",
  "referencia_transaccion": "pi_...",
  "fecha_pago": "2026-11-05T10:00:00Z",
  "estado": "PAGADO",
  "url_checkout": "...",
  "expira_en": "...",
  "created_at": "...",
  "cita_fecha": "2026-11-05",
  "cita_hora": "09:30",
  "medico_nombre": "Dr. Juan Pérez",
  "especialidad_nombre": "Medicina General",
  "tipo_consulta": "Presencial",
  "comprobante": { ... }
}
```

**`ComprobanteResponse`**
```json
{
  "id_comprobante": 1,
  "id_pago": 1,
  "numero_comprobante": "REC-20261105-000001",
  "tipo_comprobante": "RECIBO",
  "fecha_emision": "2026-11-05T10:00:00Z",
  "archivo_url": "https://storage.../comprobante_REC-....pdf",
  "estado": "EMITIDO"
}
```

**`CitaPendientePago`**
```json
{
  "id_cita": 123,
  "fecha_cita": "2026-11-05",
  "hora_inicio": "09:30",
  "hora_fin": "10:00",
  "medico_nombre": "Dr. Juan Pérez",
  "especialidad_nombre": "Medicina General",
  "tipo_consulta": "Presencial",
  "estado_cita": "PENDIENTE",
  "monto": 150.00,
  "moneda": "BOB",
  "estado_pago": null,
  "id_pago": null
}
```

**`DispositivoCreate` (registro de dispositivo push)**
```json
{
  "token": "fcm_token_...",
  "plataforma": "ANDROID"
}
```
- `token`: string, 1–4096 caracteres, no vacío
- `plataforma`: `"ANDROID"` o `"IOS"` (default `"ANDROID"`)

**Respuesta registro dispositivo**
```json
{
  "id_dispositivo": 42,
  "plataforma": "ANDROID"
}
```

## 5. Flujo de Pago Confirmado y Push

El sistema SHALL:

1. Recibir el pago confirmado vía webhook de Stripe, sincronización manual (`/sincronizar`) o pago simulado (`/simular-pago`).
2. En `_finalizar_pago`, tras `db.commit()`:
   - Marcar `estado = "PAGADO"` y `fecha_pago`.
   - Si la cita está `PENDIENTE`, cambiarla a `CONFIRMADA`.
   - Crear el `Comprobante` (número `REC-YYYYMMDD-NNNNNN`, tipo `RECIBO`, estado `EMITIDO`) y generar el PDF.
   - **Llamar `notificar_pago_confirmado(db, pago)`** — nunca lanza excepciones; si FCM falla, el pago ya está confirmado y no se revierte.
3. `notificar_pago_confirmado` SHALL:
   - Verificar que el proveedor push esté configurado (`avisos.push_configurado()`).
   - Verificar que el usuario exista, esté `ACTIVO` y tenga `notificaciones_push = true`.
   - Resolver `id_clinica` del pago o del usuario.
   - Para cada dispositivo activo del usuario en esa clínica: descifrar el token FCM (Fernet, clave `CU17_DEVICE_TOKEN_KEY`) y enviar vía `avisos.enviar_fcm_mensaje`.
   - Push: título `"Pago confirmado"`, cuerpo `"Tu pago fue confirmado."` (o con número de comprobante), data `{tipo: "PAGO_CONFIRMADO", id_pago, id_cita, numero_comprobante}`.

## 6. Variables de Entorno

| Variable | Descripción | Ejemplo |
|---|---|---|
| `STRIPE_SECRET_KEY` | Clave secreta de Stripe | `sk_test_...` |
| `STRIPE_PUBLISHABLE_KEY` | Clave pública de Stripe | `pk_test_...` |
| `STRIPE_WEBHOOK_SECRET` | Secreto del webhook Stripe | `whsec_...` |
| `PAYMENT_PUBLIC_BASE_URL` | URL pública para retornos y QR | `https://backend-telemedicina.onrender.com` |
| `CU17_FCM_PROJECT_ID` | ID del proyecto Firebase (reutilizado CU17) | `telemedicina-2de88` |
| `CU17_FCM_SERVICE_ACCOUNT_FILE` | Ruta a la cuenta de servicio FCM | `secrets/firebase-service-account.json` |
| `CU17_DEVICE_TOKEN_KEY` | Clave Fernet para cifrar tokens FCM | `...` |

## 7. Reglas de Negocio y Seguridad

- **Aislamiento tenant:** Cada endpoint filtra por `id_clinica` del usuario autenticado (`get_current_user` + `get_current_tenant_id`). Un usuario no puede ver/pagar citas ni comprobantes de otro tenant.
- **Autenticación:** Todos los endpoints protegidos requieren `Authorization: Bearer <JWT_ACCESS_TOKEN>`.
- **Push solo si está activo:** El usuario debe tener `estado = "ACTIVO"` y `notificaciones_push = true` para recibir push.
- **El pago no se revierte si falla el push:** `notificar_pago_confirmado` captura toda excepción y retorna 0.
- **Web sin Firebase:** La web y Flutter web no inicializan Firebase ni piden permisos de notificaciones.

## 8. Criterios de Aceptación (Gherkin)

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
