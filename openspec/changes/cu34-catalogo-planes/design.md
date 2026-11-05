## Context
Decisiones explícitas del usuario prevalecen sobre el prototipo anual. Reutilizar get_db síncrono, Base y layout administrativo existentes.

## Goals / Non-Goals
Implementar CU34 completo. No implementar CU31/CU35/CU36 ni inventar suscripciones.

## Decisions
La ubicación auth/planes es funcional. Siguiendo `auth/clinicas`, Plan/VersionPlan residen en `auth/models.py`; schemas/service/dependencies/router son específicos del caso. El archivo central no importa routers ni servicios. Alembic importa las clases una sola vez desde el central. En Angular se sigue ClinicasService: cliente HTTP singleton en `core/services`, tipos de contrato en `core/models` y pantalla en `features/auth/planes`. No se crean fachadas ni copias en las rutas anteriores.

Plan mantiene contador de versión; VersionPlan es append-only. FOR UPDATE y compare-and-swap evitan ediciones perdidas. PostgreSQL añade trigger de inmutabilidad y UNIQUE. Importes Decimal; JSON de tarifas guarda cadenas. Catálogo global con autorización estricta por rol global conocido, sin fallbacks por ID de rol. Auditoría usa helper existente con NULL permitido solo para tablas del catálogo. UI usa formularios reactivos, signals y servicios tipados, sin mocks de producción.

## Migration Plan
Nueva revisión descendiente de cu17_backup_merge_015. Crea planes/versiones_plan y ajusta nulabilidad + CHECK de auditoria. No se ejecuta contra Neon. Prueba aislada de upgrade/downgrade, bloqueo concurrente e inmutabilidad.

El modelo Usuario declaraba id_clinica NOT NULL aunque la migración 001 lo crea nullable y el rol global se incorporó en d2e3f4a5b6c7. Se alinea solo el mapeo ORM con ese esquema existente; no se cambian datos, IDs, autenticación ni sesiones. El downgrade CU34 se permite vacío y rechaza catálogos con historial o auditorías globales para no borrarlos silenciosamente.

## Risks / Trade-offs
CU31 aún no existe: el contrato de IDs y condiciones debe reutilizarse, pero no se puede verificar renovación. Servicios y unidades de excedentes son vocabulario explícito del catálogo; no motores de consumo. PostgreSQL local temporal y aplicación de demo independiente evitan scheduler y datos reales.
