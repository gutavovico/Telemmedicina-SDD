# Audit Log Specification (CU21)

**Capability ID:** `audit-log`  
**Caso de Uso Asociado:** CU21 - Consultar Bitácora de Auditoría Clínica (HU1-38, HU1-39, HU1-40, HU1-41, HU1-42)  
**Requisitos Funcionales:** RF-22, RF-23  
**Requisitos No Funcionales:** RNF-03, RNF-06, RNF-07  
**Modelo de Servicio:** SaaS Multitenant (Shared Database, Shared Schema)  
**Materia:** Sistemas de Información II (SI2) - Grupo 3  
**Estado:** Especificación Formal Consolidada (OpenSpec / SDD)  

---

## Purpose
The system SHALL proveer un módulo de auditoría clínica que registre de forma inmutable e inalterable todas las operaciones realizadas sobre las historias clínicas e información administrativa sensible dentro de la plataforma SaaS Multitenant, garantizando trazabilidad completa, aislamiento por `tenant_id: UUID`, seguridad y cumplimiento normativo de confidencialidad.

---

## Overview & Scope

### 1. Propósito y Límites del Sistema
El caso de uso **CU21: Consultar Bitácora de Auditoría Clínica** comprende:
1. El **registro automático e inmutable** de todas las operaciones relevantes (INSERT, UPDATE, DELETE, SELECT) sobre tablas clínicas y administrativas del sistema.
2. La **consulta paginada y filtrada** del historial de auditoría por parte de usuarios autorizados (Administrador, Auditor).
3. La **exportación** del historial filtrado en formatos PDF y Excel.

El módulo opera exclusivamente en el **Portal Web Administrativo (Angular)** y el **Backend API RESTful (FastAPI)** para el Sprint 1. No aplica a la aplicación móvil Flutter.

### 2. Actores del Sistema
| Actor | Rol en el CU21 |
|---|---|
| **Administrador del sistema** | Acceso total al módulo de auditoría: consultar, filtrar y exportar todos los registros de su tenant. |
| **Auditor médico** | Rol con permisos específicos para consultar y exportar la bitácora dentro de su tenant. |
| **Sistema** | Registra automáticamente cada evento de auditoría como efecto lateral de las operaciones CRUD. |

### 3. Precondiciones
1. The user SHALL be authenticated with a valid JWT token containing the `tenant_id` claim (CU01).
2. The user SHALL possess the role `Administrador` or `Auditor` within the authenticated tenant.
3. The `bitacora_auditoria` table SHALL exist in the database with the automatic recording mechanisms implemented.

### 4. Reglas de Negocio (RN)
- **RN-CU21-01 (Inmutabilidad Absoluta):** The audit log table SHALL be INSERT-ONLY. The system SHALL NOT permit UPDATE or DELETE operations on audit records at the application level or database level. Any attempt to modify or delete an audit record SHALL be rejected.
- **RN-CU21-02 (Registro Obligatorio por Operación):** The system SHALL automatically record an audit entry for every INSERT, UPDATE, DELETE, and SELECT operation performed on clinical and administrative tables, as well as session authentication events (LOGIN, LOGOUT). For UPDATE, both the previous state (`datos_anteriores`) and new state (`datos_nuevos`) SHALL be captured. For DELETE, only the previous state. For INSERT, only the new state. For SELECT, LOGIN, and LOGOUT, data states are optional or null.
- **RN-CU21-03 (Campos Obligatorios por Registro):** Each audit record SHALL include: `tenant_id` (UUID), `id_usuario` (BIGINT), `tabla_afectada` (VARCHAR), `registro_id` (BIGINT), `accion` (VARCHAR: INSERT|UPDATE|DELETE|SELECT|LOGIN|LOGOUT), `descripcion` (TEXT), `datos_anteriores` (JSONB, nullable), `datos_nuevos` (JSONB, nullable), `direccion_ip` (VARCHAR), `fecha_hora` (TIMESTAMP).
- **RN-CU21-04 (Aislamiento Estricto por Tenant):** Audit records SHALL be filtered by `tenant_id` in all queries. A user SHALL NOT access audit records belonging to a different `tenant_id`. Cross-tenant access SHALL respond with `404 Not Found`.
- **RN-CU21-05 (Sanitización de Datos Sensibles):** The system SHALL exclude sensitive fields (`password`, `token_version`, `refresh_token`, hashed passwords) from the JSONB payloads `datos_anteriores` and `datos_nuevos` before inserting the audit record.
- **RN-CU21-06 (Restricción de Acceso RBAC):** Only users with roles `Administrador` or `Auditor` SHALL access the audit log endpoints. Unauthorized users SHALL receive `403 Forbidden`.

### 5. Flujos de Trabajo

#### 5.1 Flujo Principal: Consulta de Bitácora de Auditoría (Web - Administrador/Auditor)
1. The authorized user navigates to the audit module from the admin panel sidebar ("Bitácora").
2. The system SHALL present a paginated table with audit records ordered by `fecha_hora` descending.
3. The user MAY apply filters: date range (`fecha_inicio`, `fecha_fin`), user (`id_usuario`), action type (`accion`), affected table (`tabla_afectada`), record ID (`registro_id`).
4. The system SHALL refresh results in real-time based on applied filters.
5. The user MAY expand individual records to view `datos_anteriores` and `datos_nuevos` JSONB payloads.
6. The table SHALL display: Fecha/Hora, Usuario, Acción, Tabla Afectada, Registro ID, IP, Descripción.

#### 5.2 Flujo Secundario: Exportación de Bitácora (PDF/Excel)
1. The user clicks "Exportar PDF" or "Exportar Excel" after optionally applying filters.
2. The system SHALL generate the export file server-side applying the same filters and tenant isolation.
3. The system SHALL return a downloadable binary stream (`application/pdf` or `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`).

#### 5.3 Flujo Automático: Registro de Evento de Auditoría (Sistema)
1. A user performs a CRUD operation on a clinical or administrative table via any endpoint.
2. The system SHALL extract `tenant_id`, `id_usuario`, and `direccion_ip` from the request context.
3. The system SHALL determine the `tabla_afectada`, `registro_id`, `accion`, and capture `datos_anteriores` / `datos_nuevos` as applicable.
4. The system SHALL insert an immutable record into `bitacora_auditoria`.

### 6. Flujos Alternativos / Excepciones
- **Sin registros:** The system SHALL display "No hay registros de auditoría que coincidan con los filtros aplicados."
- **Filtros inválidos:** The system SHALL notify the user and retain the previous filter state.
- **Intento de edición/eliminación de registros:** The system SHALL reject the operation (no endpoint exposed for mutation).
- **Acceso no autorizado:** Users without `Administrador` or `Auditor` role SHALL receive `403 Forbidden`.

---

## Data Model

### Table: `bitacora_auditoria`

| Campo | Tipo | Constraints | Descripción |
|---|---|---|---|
| `id_auditoria` | BIGINT | PK, AUTOINCREMENT | Clave primaria |
| `tenant_id` | UUID | NOT NULL, FK → `clinicas.id`, INDEX | Identificador del inquilino |
| `id_usuario` | BIGINT | NOT NULL, FK → `usuarios.id_usuario` | Usuario que realizó la operación |
| `tabla_afectada` | VARCHAR(100) | NOT NULL | Nombre de la tabla afectada |
| `registro_id` | BIGINT | NULL | ID del registro afectado en la tabla |
| `accion` | VARCHAR(50) | NOT NULL | Tipo: `INSERT`, `UPDATE`, `DELETE`, `SELECT` |
| `descripcion` | TEXT | NULL | Descripción textual de la operación |
| `datos_anteriores` | JSONB | NULL | Estado previo del registro (UPDATE/DELETE) |
| `datos_nuevos` | JSONB | NULL | Estado nuevo del registro (INSERT/UPDATE) |
| `direccion_ip` | VARCHAR(45) | NULL | IP del cliente (IPv4/IPv6) |
| `fecha_hora` | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Momento exacto de la operación |

**Indexes:**
- `idx_bitacora_tenant_fecha` → `(tenant_id, fecha_hora DESC)`
- `idx_bitacora_tenant_usuario` → `(tenant_id, id_usuario)`
- `idx_bitacora_tenant_accion` → `(tenant_id, accion)`
- `idx_bitacora_tenant_tabla` → `(tenant_id, tabla_afectada)`

**Constraints:**
- INSERT-ONLY: No UPDATE, no DELETE permissions for the application database role.

---

## Requirements

### Requirement: Tenant-isolated immutable audit log
The system SHALL record every clinical and administrative mutation as an immutable audit entry filtered by tenant, and expose paginated filtered queries only to authorized roles.

#### Scenario: Admin queries audit log within tenant
- **WHEN** an authenticated Administrador of a tenant sends GET /api/v1/audit-log with pagination
- **THEN** the system returns 200 OK with records ordered by fecha_hora descending belonging only to that tenant

#### Scenario: Cross-tenant audit isolation
- **WHEN** a user authenticated in one tenant queries the audit log
- **THEN** the system does not return records belonging to another tenant

#### Scenario: Unauthorized role is forbidden
- **WHEN** a user without Administrador or Auditor role queries the audit log
- **THEN** the system returns 403 Forbidden

### Requirement: Audit export and immutability
The system SHALL allow PDF/Excel export with the same tenant filter and SHALL reject any mutation of audit records.

#### Scenario: Export audit log as PDF
- **WHEN** an authorized user requests the PDF export with date filters
- **THEN** the system returns 200 OK with Content-Type application/pdf

## Gherkin Scenarios

### Feature: Consulta de Bitácora de Auditoría

```gherkin
Feature: CU21 - Bitácora de Auditoría Clínica

  Background:
    Given the tenant "Clínica Central" exists and is active
    And the user "admin@clinica.com" is authenticated with role "Administrador" in tenant "Clínica Central"
    And audit records exist for tenant "Clínica Central"

  Scenario: Admin consulta la bitácora sin filtros
    When the user sends GET /api/v1/audit-log?page=1&page_size=20
    Then the response status SHALL be 200 OK
    And the response SHALL contain a paginated list of audit records
    And records SHALL be ordered by fecha_hora descending
    And all records SHALL belong to tenant "Clínica Central"

  Scenario: Admin filtra bitácora por rango de fechas
    When the user sends GET /api/v1/audit-log?fecha_inicio=2026-09-01&fecha_fin=2026-09-06
    Then the response status SHALL be 200 OK
    And all returned records SHALL have fecha_hora between "2026-09-01T00:00:00Z" and "2026-09-06T23:59:59Z"

  Scenario: Admin filtra bitácora por tipo de acción
    When the user sends GET /api/v1/audit-log?accion=UPDATE
    Then the response status SHALL be 200 OK
    And all returned records SHALL have accion equal to "UPDATE"

  Scenario: Admin filtra bitácora por usuario
    When the user sends GET /api/v1/audit-log?id_usuario=5
    Then the response status SHALL be 200 OK
    And all returned records SHALL have id_usuario equal to 5

  Scenario: Admin exporta bitácora en PDF
    When the user sends GET /api/v1/audit-log/export/pdf?fecha_inicio=2026-09-01&fecha_fin=2026-09-06
    Then the response status SHALL be 200 OK
    And the Content-Type header SHALL be "application/pdf"
    And the response body SHALL be a valid PDF file

  Scenario: Admin exporta bitácora en Excel
    When the user sends GET /api/v1/audit-log/export/excel?fecha_inicio=2026-09-01&fecha_fin=2026-09-06
    Then the response status SHALL be 200 OK
    And the Content-Type header SHALL be "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

  Scenario: Aislamiento multitenant - no se ven registros de otro tenant
    Given the tenant "Clínica Norte" also exists with its own audit records
    When the user authenticated in "Clínica Central" sends GET /api/v1/audit-log
    Then the response SHALL NOT contain any records belonging to "Clínica Norte"

  Scenario: Usuario sin rol autorizado recibe 403
    Given the user "medico@clinica.com" is authenticated with role "Médico" in tenant "Clínica Central"
    When the user sends GET /api/v1/audit-log
    Then the response status SHALL be 403 Forbidden

  Scenario: Inmutabilidad - no se pueden eliminar registros
    When any user attempts to DELETE an audit record
    Then the system SHALL reject the operation
    And no audit record SHALL be removed from the database

  Scenario: Registro automático de evento INSERT
    When a user creates a new patient record via POST /api/v1/pacientes
    Then the system SHALL automatically insert an audit record with accion "INSERT"
    And the audit record SHALL contain datos_nuevos with the patient data
    And the audit record SHALL NOT contain sensitive fields like "password"

  Scenario: Sin registros muestra mensaje vacío
    Given no audit records exist matching the applied filters
    When the user sends GET /api/v1/audit-log?accion=DELETE
    Then the response status SHALL be 200 OK
    And the response data array SHALL be empty
    And the total count SHALL be 0
```
