# Tasks: CU09 – Gestionar Fichas Médicas y Expediente Clínico Dinámico

## 1. Backend (`backend_Telemedicina`)
- [x] 1.1 Crear modelos SQLAlchemy de Fichas Médicas en `app/modules/medical_records/fichas/models.py` (`FichaClinica`, `correlativo`, `signos_vitales` JSONB, `secciones_dinamicas` JSONB).
- [x] 1.2 Reexportar `FichaClinica` en `app/modules/medical_records/models.py` asegurando conexión con `clinicas`, `pacientes`, `medicos`, `servicios_medicos` y `diagnosticos`.
- [x] 1.3 Implementar esquemas Pydantic v2 en `app/modules/medical_records/fichas/schemas.py` (`FichaCreate`, `FichaClinicaUpdate`, `FichaResponse`, `FichaListResponse`, `FichaCancelRequest`).
- [x] 1.4 Implementar servicio en `app/modules/medical_records/fichas/service.py` con generación de correlativo atómico `FICH-YYYYMMDD-XXXX` y control de concurrencia (409 Conflict).
- [x] 1.5 Implementar endpoints en `app/modules/medical_records/fichas/router.py` (`POST /`, `GET /`, `GET /{id}`, `PATCH /{id}/clinica`, `POST /{id}/cancelar`).
- [x] 1.6 Montar router de fichas en `app/modules/medical_records/router.py` bajo `/fichas` y `/medical-records/fichas`.
- [x] 1.7 Generar migración Alembic lineal derivada de `c3d4e5f6a7b8` en `alembic/versions/005_tablas_fichas_cu09.py` y actualizar `alembic/env.py`.
- [x] 1.8 Desarrollar batería de pruebas en `tests/test_cu09_fichas.py` validando emisión, concurrencia (409), llenado clínico y aislamiento multitenant.

## 2. Frontend Web (`frontend_Telemedicina`)
- [x] 2.1 Definir interfaces TypeScript en `src/app/core/models/ficha.models.ts` (`FichaClinica`, `SignosVitales`, `SeccionesDinamicas`, `FichaCreateRequest`, `FichaClinicaUpdateRequest`).
- [x] 2.2 Implementar servicio reactivo `src/app/core/services/ficha.service.ts` con HttpClient y manejo de errores.
- [x] 2.3 Crear componente `ficha-emision` en `src/app/features/medical-records/fichas/ficha-emision/` con selector de turnos en cascada y pre-triaje.
- [x] 2.4 Crear componente `ficha-detalle` en `src/app/features/medical-records/fichas/ficha-detalle/` con renderizado dinámico JSONB por especialidad y autocompletado CIE-10.
- [x] 2.5 Crear componente `ficha-list` en `src/app/features/medical-records/fichas/ficha-list/` con tabla reactiva, filtros y badges semánticos.
- [x] 2.6 Registrar rutas `/fichas`, `/fichas/nueva`, `/fichas/:id` en `app.routes.ts` y `app.routes.server.ts` con `RenderMode.Client`.
- [x] 2.7 Añadir enlace de acceso directo a "Fichas Médicas" en `header.html` (desktop, móvil y menú de usuario).

## 3. Frontend Móvil (`mobile_telemedicina`)
- [x] 3.1 Implementar capa Data en `lib/features/medical_records/data/`: `ficha_model.dart` y `ficha_remote_datasource.dart`.
- [x] 3.2 Implementar capa Domain en `lib/features/medical_records/domain/`: `ficha_entity.dart`, `ficha_repository.dart` y usecases.
- [x] 3.3 Implementar capa Presentation: `ficha_provider.dart` (gestión de estado reactivo).
- [x] 3.4 Crear pantallas móviles: `fichas_screen.dart` (historial y estado) y `book_ficha_screen.dart` (emisión con correlativo).
- [x] 3.5 Registrar URLs en `api_config.dart` y declarar rutas `/fichas` y `/fichas/nueva` en `main.dart`.

## 4. Validación de Quality Gates
- [x] 4.1 Ejecutar `openspec validate --all` y `openspec doctor`.
- [x] 4.2 Ejecutar `pytest -q` y `alembic heads` en Backend.
- [x] 4.3 Ejecutar `npm run build` en Frontend Web.
- [x] 4.4 Ejecutar `flutter analyze` en Frontend Móvil.
- [x] 4.5 Actualizar `walkthrough.md` y presentar reporte final.
