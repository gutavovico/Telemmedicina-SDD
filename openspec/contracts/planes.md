# CU34 — API del catálogo (2026-11-03)

Paquete auth/planes; UI features/auth/planes bajo /admin/planes. Todos los endpoints requieren Bearer JWT y superadmin global. No tenant_id ni id_clinica en entradas; campos extra rechazados. No pagos, suscripciones, renovación ni opciones anuales.

Organización compatible con clínicas: modelos SQLAlchemy compartidos en `app/modules/auth/models.py`; esquemas, lógica transaccional, permisos y router en `auth/planes`. Alembic importa Plan/VersionPlan desde el archivo central y usa la misma Base. En frontend, tipos en `core/models/plan.models.ts`, cliente HTTP en `core/services/planes.service.ts` y componentes en `features/auth/planes`. No hay definiciones ni implementaciones duplicadas.

## Modelo
- Plan: id BIGINT PK, codigo VARCHAR(50) único, activo BOOLEAN, version_actual INTEGER positiva, creado_en/actualizado_en TIMESTAMPTZ. Código normalizado a mayúsculas, patrón [A-Z0-9][A-Z0-9_-]{0,49}. Inmutable tras creación.
- VersionPlan: id BIGINT PK, plan_id FK RESTRICT, numero INTEGER positivo UNIQUE(plan_id,numero), nombre VARCHAR(150), descripcion VARCHAR(2000) nullable, precio_mensual NUMERIC(14,2), moneda BOB, ciclo MENSUAL, servicios_incluidos JSON, limite_medicos/limite_sedes/limite_consultas INTEGER nullable, tarifas_excedentes JSON, demora_pago_dias INTEGER, creado_en TIMESTAMPTZ, creado_por FK usuarios RESTRICT.
- Toda condición forma una instantánea inmutable. version_actual es un contador del Plan usado también para compare-and-swap; no reemplaza el ID de versión contratado de futuros consumidores.
- Dinero de entrada/salida: cadenas decimales, no float. Máximo 999999999999.99; sin exponente, NaN ni Infinity. Salida normalizada a dos decimales. Precio 0.00 gratuito.
- Enteros estrictos 0..2147483647; NULL = ilimitado; 0 = ninguna unidad incluida. Consultas por ciclo mensual de suscripción, no por mes calendario. Días de demora calendario, sin suspensión implementada.
- Servicios estables: AGENDA_TELECONSULTA, RECETAS_DIGITALES, LABORATORIO, LISTA_ESPERA, REPORTES_AUDITORIA, TRIAJE_IA, SUBDOMINIO_PROPIO, INTEGRACIONES. Lista sin duplicados; puede estar vacía. Son prestaciones SaaS, no filas de servicios_medicos.
- Tarifa: {recurso: MEDICOS|SEDES|CONSULTAS, unidad: MEDICO_CICLO_MENSUAL|SEDE_CICLO_MENSUAL|CONSULTA, precio: decimal-string}. Máximo una por recurso; correspondencia recurso/unidad obligatoria. Recurso ilimitado no acepta tarifa. Lista vacía = ninguna tarifa configurada. No define cobro ni habilita sobreuso; CU36 deberá acordar medición y liquidación.
- No importes ni nombres de planes de producción predeterminados. Sin máximo de planes.

## Rutas
Prefijo único `/api/v1/planes`.

| Método/ruta relativa | Entrada | Salida |
|---|---|---|
| GET /opciones | ninguna | servicios [{codigo,nombre}], recursos [{recurso,unidad,nombre}], moneda, ciclo |
| POST raíz | codigo y campos completos de condiciones | 201 PlanDetalle |
| GET raíz | q (0..150), estado ACTIVO/INACTIVO opcional, page>=1, per_page 1..100 | {items: PlanDetalle[],total,page,per_page} |
| GET /{id} | ID positivo | PlanDetalle |
| POST /{id}/versiones | version_base>=1 y condiciones completas | 201 PlanDetalle |
| GET /{id}/versiones | page/per_page | {items: VersionResponse[],total,page,per_page}, número descendente |
| GET /{id}/versiones/{numero} | positivos | VersionResponse |
| PATCH /{id}/estado | {activo:false} literal booleano | PlanDetalle, 200 idempotente |

PlanDetalle: {id,codigo,activo,version_actual,creado_en,actualizado_en,version:VersionResponse}. VersionResponse contiene todos los campos de VersionPlan; tarifas y precios serializados como cadenas.

## Errores y transacciones
401 no autenticado, 403 actor no autorizado, 404 PLAN_NOT_FOUND / PLAN_VERSION_NOT_FOUND; 409 PLAN_CODE_EXISTS / PLAN_STALE_VERSION / PLAN_INACTIVE / PLAN_CONCURRENT_CHANGE; 422 validación FastAPI (detail como lista). Errores de dominio: {detail:string,code:string}. Nunca devolver SQL ni secretos.

La nueva versión requiere bloqueo FOR UPDATE sobre Plan y actualización condicionada por version_actual/activo. Único (plan_id,numero) como respaldo. Desactivación comparte bloqueo y compare-and-swap. Auditoría global, id_clinica NULL, misma transacción, sin commit interno. Los demás eventos mantienen clínica obligatoria por CHECK. No se expone eliminación ni reactivación.

## Integraciones pendientes
CU31 recibirá plan_id/version_id/ciclo/precio/moneda; CU35 consultará condiciones de origen/destino y estado para nuevas contrataciones; CU36 consumirá límites/tarifas de versión contratada. No se crean suscripciones ni gateways. La verificación de renovación real queda pendiente de esos casos.
