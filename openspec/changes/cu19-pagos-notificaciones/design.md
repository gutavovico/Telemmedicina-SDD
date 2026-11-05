# Technical Design: CU19 Pagos + Notificaciones Push

## Context

Ver `proposal.md`. Backend FastAPI con SQLAlchemy síncrono (`Session`, precedente pagos/CU19), BD PostgreSQL (Neon Serverless) con `id_clinica` como discriminador de tenant. Web Angular 19 + Tailwind v4; móvil Flutter + ChangeNotifier. Firebase solo en APK Android.

## Goals / Non-Goals

**Goals:**
- Procesar pagos de citas/teleconsultas mediante Stripe Checkout o modo simulado.
- Emitir comprobante digital en PDF al confirmarse el pago.
- Enviar push "Pago confirmado" a la APK Android tras `db.commit()` del pago.
- Registrar/revocar tokens FCM de dispositivos móviles sin depender de permisos de tratamientos.
- Web y Flutter web sin Firebase ni permisos de push.

**Non-Goals:**
- Crear tablas o migraciones nuevas (se reutilizan `pagos`, `comprobantes`, `tratamiento_dispositivos` de CU17).
- Push en iOS/web (solo Android APK).
- WebSockets (el móvil usa polling/token al login).

## Decisions

### 1. Sin DDL: reutilizar infraestructura de CU17

La tabla `tratamiento_dispositivos` y el cifrado Fernet de CU17 se reutilizan para registrar tokens FCM. No se crean tablas ni migraciones. El módulo `app/modules/notificaciones/` expone endpoints genéricos `/notificaciones/dispositivos` (POST/DELETE) sin depender de permisos de tratamientos.

### 2. Hook de push tras `db.commit()` en `_finalizar_pago`

En `app/modules/payments/service.py::_finalizar_pago`, tras `db.commit()` y `db.refresh(pago)`, se llama `notificar_pago_confirmado(db, pago)`. El servicio captura toda excepción (try/except amplio) para que un fallo de FCM **no revierta** el pago ya confirmado.

### 3. Push solo en Android (`!kIsWeb && android`)

`PushService` en el móvil se inicializa solo cuando `!kIsWeb && defaultTargetPlatform == TargetPlatform.android`. En web se usa un stub vacío (`push_service_stub.dart`) sin importar Firebase ni `flutter_local_notifications`. La selección se hace con export condicional de Dart: `export 'push_service_android.dart' if (dart.library.html) 'push_service_stub.dart'`.

### 4. Canal de notificaciones `cu19_pagos`

`AndroidManifest.xml` declara `POST_NOTIFICATIONS` y meta-data `com.google.firebase.messaging.default_notification_channel_id = cu19_pagos`. El canal se crea con `Importance.high`.

### 5. Navegación al tocar la notificación

Al tocar una notificación de tipo `PAGO_CONFIRMADO` (o sin tipo), el móvil navega con `prescriptionNavigatorKey.currentState?.pushNamed('/pagos')`.

### 6. Registro de token al login, revocación al logout

`auth_controller.dart` llama `PushService.instance.registerCurrentToken()` tras login exitoso y `PushService.instance.unregisterDevice()` al cerrar sesión. El `id_dispositivo` se guarda en `SharedPreferences` (clave `cu19_push_device_id`) para revocarlo en logout.

### 7. Rotación de token FCM

`FirebaseMessaging.instance.onTokenRefresh` vuelve a registrar el token en el backend cuando FCM lo rota.

## Risks / Trade-offs

- **[Riesgo: CI falla si se importan Firebase en web]** → Mitigación: export condicional de Dart y stub vacío para web. Verificado con `flutter analyze` (0 errores) y `flutter test` (198 passed).
- **[Riesgo: espacio en disco para build de APK]** → Mitigación: caché de Gradle movida a `D:\gradle-home`, JDK 21 en `D:\jdk21`, PUB_CACHE en `D:\pub-cache`.
- **[Riesgo: push falla y pago se revierte]** → Mitigación: `notificar_pago_confirmado` captura toda excepción y retorna 0; el pago ya fue confirmado antes del push.
