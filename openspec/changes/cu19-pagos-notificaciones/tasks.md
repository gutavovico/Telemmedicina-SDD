# Tasks: CU19 Pagos + Notificaciones Push

## [Fase 0: SDD]
- [x] T0.1: `proposal.md` (DTOs, endpoints, reutilización de tablas CU17, flujo push).
- [x] T0.2: `specs/cu19-pagos-notificaciones.spec.md` (RFC 2119 + Gherkin, criterios de aceptación).
- [x] T0.3: `design.md` (decisiones, riesgos, push solo Android).
- [x] T0.4: `contracts/pagos.md` + `contracts/notificaciones.md` consolidados.

## [Fase 1: Backend — FastAPI]
- [x] T1.1: `app/modules/payments/` (`router.py`, `service.py`, `schemas.py`, `models.py`).
- [x] T1.2: Endpoints de pagos (`/pagos` y `/api/v1/pagos`): checkout, pendientes, mis-pagos, webhook Stripe, sincronizar, comprobante, QR.
- [x] T1.3: `app/modules/notificaciones/` (`router.py`, `service.py`): POST/DELETE `/notificaciones/dispositivos`.
- [x] T1.4: Reutilizar `avisos.py` de CU17 (`descifrar_token`, `enviar_fcm_mensaje`, `push_configurado`, `cifrar_token`, `hash_token`).
- [x] T1.5: Hook `notificar_pago_confirmado(db, pago)` tras `db.commit()` en `_finalizar_pago` (sin revertir pago si FCM falla).
- [x] T1.6: Registro de routers en `app/main.py` (raíz y `/api/v1`).
- [x] T1.7: Variables de entorno en `.env` (gitignored): `CU17_FCM_PROJECT_ID`, `CU17_FCM_SERVICE_ACCOUNT_FILE`, `CU17_DEVICE_TOKEN_KEY`.
- [x] T1.8: `.gitignore` protege `secrets/`.
- [x] T1.9: Tests CU19 + CU17: 27 passed, 14 skipped.

## [Fase 2: Frontend Web — Angular]
- [x] T2.1: Consumo de endpoints de pagos (checkout, mis pagos, comprobante).
- [x] T2.2: No inicializar Firebase ni pedir permisos de push en web.

## [Fase 3: Móvil — Flutter Clean Architecture]
- [x] T3.1: Dependencias `firebase_core ^5.1.0`, `firebase_messaging ^17.0.1`, `flutter_local_notifications ^22.3.3`.
- [x] T3.2: Plugin `com.google.gms.google-services` v4.4.4 en `settings.gradle.kts` y `app/build.gradle.kts`.
- [x] T3.3: `AndroidManifest.xml`: permiso `POST_NOTIFICATIONS`, canal `cu19_pagos`, icono.
- [x] T3.4: `google-services.json` del proyecto `telemedicina-2de88`.
- [x] T3.5: `lib/core/notifications/push_service.dart` (export condicional Android/web).
- [x] T3.6: `lib/core/notifications/push_service_android.dart` (FCM real, canal, registro de token).
- [x] T3.7: `lib/core/notifications/push_service_stub.dart` (no-op para web).
- [x] T3.8: `lib/core/config/api_config.dart`: `pushDevicesUrl`, `pushDeviceUrl(id)`.
- [x] T3.9: `lib/main.dart`: `PushService.instance.initialize()` antes de `runApp`.
- [x] T3.10: `lib/features/auth/.../auth_controller.dart`: registra token al login, revoca al logout.
- [x] T3.11: `flutter analyze`: 0 errores nuevos. `flutter test`: 198 passed.

## [Fase 4: Verificación]
- [x] T4.1: `import app.main` OK, 4 rutas `/notificaciones`, `push_configurado() == True`.
- [x] T4.2: `flutter analyze` y `flutter test` en verde.
- [ ] T4.3: `openspec validate --specs` (sin CLI disponible en este entorno).
- [ ] T4.4: Prueba E2E real en emulador Pixel_7 (pendiente por espacio en disco para build APK).
