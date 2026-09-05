# Technical Design: Formalización de Línea Base del Sprint 0 (SaaS Multitenant Baseline)

## Context
El código desarrollado durante el Sprint 0 en `backend_Telemedicina/app/modules/` implementó autenticación básica, usuarios, roles y médicos, pero con referencias a un esquema centralizado y llamadas sin particionamiento por `tenant_id`. Para formalizar la arquitectura SaaS Multitenant (Shared Database, Shared Schema en Neon PostgreSQL), este diseño describe cómo se estructuran las entidades, la resolución de inquilino y los contratos de API.

Ver motivación y alcance en `proposal.md`.

## Goals / Non-Goals

**Goals:**
- Asegurar aislamiento estricto por `tenant_id: UUID` en todas las tablas transaccionales de auth, usuarios, roles y médicos.
- Implementar unicidad compuesta por tenant: `UNIQUE(tenant_id, correo)` y `UNIQUE(tenant_id, matricula)`.
- Validar tokens JWT con claim `tenant_id` y control de versión (`token_version`) para revocación instantánea (CU24).
- Garantizar recuperación de contraseñas sin persistencia adicional usando HMAC-SHA256 y control de tasa (CU23).
- Exponer contratos de API RESTful OpenAPI 3.1 tipados y consistentes con los estándares del backend y frontends.

**Non-Goals:**
- No incluye en este change la gestión de citas (Sprint 1) ni videoconsultas WebRTC.
- No modifica la especificación de pacientes (`patient-management` - CU03), que ya fue formalizada independientemente.

## Decisions

### 1. Resolución de Tenant en Autenticación y Endpoints
- **Decisión:** Para endpoints de autenticación iniciales (`/login`, `/register`), el `tenant_id` se extrae del header `X-Tenant-ID: <UUID>` provisto por el portal de la clínica o subdominio. Para endpoints autenticados subsecuentes (`/me`, `/users`, `/medicos`), el `tenant_id` se extrae y valida prioritariamente desde el claim del token JWT Bearer.
- **Alternativa Descartada:** Permitir que el cliente envíe `tenant_id` en el cuerpo JSON del request. Se descartó para prevenir ataques de *Tenant Injection*.

### 2. Revocación de Tokens sin Estado (Token Versioning)
- **Decisión:** Cada usuario posee una columna entera `token_version: int`. Al cerrar sesión (`/logout`) o restablecer contraseña, `token_version` se incrementa en la base de datos (`+1`). En cada request protegido, se valida que el `token_version` del payload JWT coincida con el valor actual en la BD.
- **Alternativa Descartada:** Usar una tabla Redis en memoria o blacklist en BD de todos los tokens JWT emitidos. El versionado por usuario es más liviano, no requiere Redis y revoca todos los dispositivos de inmediato.

### 3. Recuperación de Contraseñas Stateless (HMAC-SHA256)
- **Decisión:** El código de 6 dígitos para `/forgot-password` y `/reset-password` se deriva mediante `HMAC-SHA256(secret, f"{user_id}:{bucket}")` donde el bucket representa ventanas temporales de 30 minutos.
- **Alternativa Descartada:** Almacenar tokens aleatorios en una tabla temporal `password_reset_tokens`. El algoritmo HMAC no requiere migraciones ni tablas adicionales y permite expiración matemática.

## Risks / Trade-offs

- **[Riesgo] Colisión de códigos HMAC en ventanas de tiempo:**
  - *Mitigación:* La función `_reset_code_for_bucket` combina el ID numérico del usuario con el bucket y un secreto criptográfico de 256 bits (`JWT_RESET_SECRET_KEY`), garantizando entropía suficiente.
- **[Riesgo] Fuerza bruta contra códigos de 6 dígitos:**
  - *Mitigación:* Implementación de `_check_reset_lockout`: un máximo de 5 intentos fallidos bloquea al usuario por 15 minutos (`HTTP 429 Too Many Requests`).
- **[Riesgo] Consultas cross-tenant en listados de médicos o usuarios:**
  - *Mitigación:* Las dependencias de FastAPI y queries SQLAlchemy inyectan explícitamente `Model.tenant_id == current_tenant.id`.
