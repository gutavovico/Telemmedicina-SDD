---
name: fastapi-backend-standards
description: Estándares arquitectónicos y de desarrollo para el backend en FastAPI (Python 3.11+). Arquitectura modular por dominio con separación por casos de uso, SQLAlchemy 2.0 asíncrono, Alembic, Pydantic v2, aislamiento estricto multitenant con tenant_id y respuestas HTTP semánticas.
---

# FastAPI Backend Standards - Plataforma SaaS Multitenant

Este estándar define las reglas obligatorias de diseño, arquitectura y codificación para el backend de la plataforma SaaS de Telemedicina implementado con **FastAPI**, **SQLAlchemy 2.0**, **Alembic**, **Pydantic v2** y **PostgreSQL (Neon Serverless)**.

---

## 1. Arquitectura Modular por Dominio y Casos de Uso

La aplicación sigue una estructura modular donde cada **Dominio** agrupa lógicamente sus **Casos de Uso** internos:

```
backend_Telemedicina/
├── app/
│   ├── core/                      # Infraestructura transversal
│   │   ├── config.py              # Settings tipados con Pydantic Settings
│   │   ├── database.py            # AsyncEngine y async_sessionmaker de SQLAlchemy 2.0
│   │   ├── security.py            # Hashing (bcrypt/argon2), JWT tokens y verificación de claims
│   │   └── multitenancy.py        # Dependencia get_current_tenant y validaciones de tenant
│   ├── modules/                   # Módulos organizados por DOMINIO
│   │   ├── <dominio>/             # Ej: medical_records, auth, appointments
│   │   │   ├── <caso_de_uso>/     # Separación por caso de uso (ej: patients, records)
│   │   │   │   ├── router.py      # Endpoints HTTP, inyección de dependencias y códigos de estado
│   │   │   │   ├── service.py     # Lógica de negocio pura, orquestación y transacciones
│   │   │   │   ├── schemas.py     # Contratos Pydantic v2 (Request, Response, Filter)
│   │   │   │   ├── models.py      # Entidades persistentes SQLAlchemy 2.0 con tenant_id
│   │   │   │   └── dependencies.py# Verificación de roles y permisos específicos
│   │   │   └── __init__.py
│   │   └── ...
│   └── main.py                    # Ensamblado de routers, middleware CORS y tenant
```

### Reglas de Organización:
- **Alta Cohesión:** Todo lo relacionado a un caso de uso (`router`, `service`, `schemas`, `models`) debe residir en su respectivo directorio `app/modules/<dominio>/<caso_de_uso>/`.
- **Cero Lógica en Routers:** Los routers en `router.py` solo deserializan peticiones, invocan servicios y retornan respuestas. La lógica de negocio y queries complejas pertenecen a `service.py`.
- **Inyección de Dependencias:** El acceso a la sesión de base de datos (`AsyncSession`), el usuario autenticado y el `tenant_id` deben inyectarse mediante dependencias de FastAPI (`Depends`).

---

## 2. SQLAlchemy 2.0 y Migraciones Alembic

### 2.1 Uso Estricto de la Sintaxis 2.0
- **Prohibido:** No utilizar la API heredada de SQLAlchemy 1.x (`session.query(...)`).
- **Obligatorio:** Utilizar la sintaxis funcional moderna con `select(...)`, `update(...)`, `delete(...)` y ejecución asíncrona:

```python
# CORRECTO (SQLAlchemy 2.0)
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

async def get_patient_by_id(db: AsyncSession, patient_id: int, tenant_id: uuid.UUID) -> Optional[Paciente]:
    stmt = select(Paciente).where(
        Paciente.id_paciente == patient_id,
        Paciente.tenant_id == tenant_id,
        Paciente.estado != "INACTIVO"
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()
```

### 2.2 Migraciones con Alembic
- Toda nueva tabla o modificación de esquema debe gestionarse mediante migraciones versionadas en `alembic/versions/`.
- Toda tabla transaccional o clínica DEBE incluir la columna `tenant_id`:
```python
sa.Column('tenant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('tenants.id', ondelete='CASCADE'), nullable=False, index=True)
```
- Debe incluirse un índice compuesto de búsqueda y unicidad:
```python
sa.Index('idx_pacientes_tenant_ci', 'tenant_id', 'ci')
sa.UniqueConstraint('tenant_id', 'ci', 'complemento', name='uq_pacientes_tenant_ci_complemento')
```

---

## 3. Pydantic v2 para Validación y Esquemas

- Utilizar la sintaxis nativa de **Pydantic v2**:
  - `model_config = ConfigDict(from_attributes=True)` en esquemas de respuesta.
  - `@field_validator` en lugar del decorador deprecado `@validator`.
- Separar claramente esquemas de entrada (`CreateRequest`, `UpdateRequest`, `PatchRequest`) y de salida (`Response`, `PaginationResponse`).
- Los esquemas de salida que representen entidades clínicas deben exponer el campo `tenant_id: UUID`.

```python
from pydantic import BaseModel, ConfigDict, EmailStr, Field
import uuid
from datetime import date, datetime

class PacienteBase(BaseModel):
    nombres: str = Field(..., max_length=100)
    apellidos: str = Field(..., max_length=100)
    ci: str = Field(..., max_length=20)
    complemento: Optional[str] = Field(default="", max_length=10)
    fecha_nacimiento: date
    genero: str = Field(..., pattern="^(M|F|OTRO)$")
    telefono: str = Field(..., max_length=20)
    correo: Optional[EmailStr] = None

class PacienteCreateRequest(PacienteBase):
    pass

class PacienteResponse(PacienteBase):
    id_paciente: int
    tenant_id: uuid.UUID
    estado: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
```

---

## 4. Aislamiento Multitenant Estricto

### 4.1 Resolución del Tenant
El `tenant_id` se resuelve centralmente mediante la dependencia `get_current_tenant`:
1. **Prioridad 1:** Claim `tenant_id` embebido en el token de acceso JWT.
2. **Prioridad 2:** Header HTTP `X-Tenant-ID: <UUID>` verificado contra la base de datos.
3. Si el inquilino no existe o se encuentra inactivo/suspendido, la petición se aborta inmediatamente con `401 Unauthorized` o `403 Forbidden`.

### 4.2 Reglas Inquebrantables de Aislamiento
1. **Filtro Obligatorio:** TODA consulta (`SELECT`), actualización (`UPDATE`) o baja (`SOFT DELETE`) DEBE incluir la condición `Model.tenant_id == current_tenant.id`.
2. **Prevención de Tenant Injection:** NUNCA aceptar el `tenant_id` en el cuerpo del request (`payload body`) enviado por el cliente en operaciones de creación. El backend asigna el `tenant_id` automáticamente desde la sesión autenticada:
```python
# CORRECTO
nuevo_paciente = Paciente(
    **request_data.model_dump(),
    tenant_id=current_tenant.id
)
```
3. **No Fuga de Información (Anti-leak):** Cuando un usuario intente consultar o mutar un registro que existe en la base de datos pero pertenece a otro tenant, el sistema DEBE retornar `404 Not Found` (como si el ID no existiera) para no revelar la existencia del registro en otra organización.

---

## 5. Códigos de Estado HTTP Semánticos y Estructura de Errores

Cada endpoint debe declarar explícitamente sus códigos de respuesta y tipos de retorno:

| Código | Significado Semántico | Caso de Uso en la Plataforma |
|---|---|---|
| **200 OK** | Solicitud exitosa | Listados, detalles por ID y actualizaciones (PUT/PATCH). |
| **201 Created** | Recurso creado exitosamente | Alta de pacientes, citas o usuarios con header `Location` opcional. |
| **400 Bad Request** | Solicitud malformada | UUID de tenant inválido, parámetros incoherentes. |
| **401 Unauthorized** | Autenticación fallida o ausente | Token JWT expirado, ausente o tenant suspendido. |
| **403 Forbidden** | Autorización denegada | Rol insuficiente (ej. paciente intentando ver listado general). |
| **404 Not Found** | Recurso inexistente o ajeno | ID no encontrado o perteneciente a otro `tenant_id`. |
| **409 Conflict** | Conflicto de negocio | Documento C.I. o correo ya registrado **en el mismo tenant**. |
| **422 Unprocessable Entity** | Fallo de validación Pydantic | Tipos de datos inválidos, campos obligatorios omitidos. |

### Formato Estándar de Respuesta de Error:
```json
{
  "detail": "Descripción comprensible del error",
  "code": "PATIENT_ALREADY_EXISTS_IN_TENANT",
  "timestamp": "2026-09-05T15:30:00Z"
}
```
