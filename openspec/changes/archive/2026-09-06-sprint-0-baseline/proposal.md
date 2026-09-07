# Proposal: Formalización de Línea Base del Sprint 0 (SaaS Multitenant Baseline)

## Why
Durante el Sprint 0 del proyecto, el equipo de desarrollo implementó los módulos iniciales de autenticación (CU01, CU24), administración de usuarios y roles (CU02, CU26), gestión de médicos (CU04) y recuperación de contraseña (CU23). Sin embargo, estas funcionalidades operaban con especificaciones manuales previas a la adopción formal de OpenSpec y carecían de la formalización explícita del aislamiento para la arquitectura **Cloud SaaS Multitenant**. 

Es imperativo formalizar estos casos de uso como especificaciones y contratos canónicos dentro de OpenSpec para que sirvan como la única fuente de verdad (Single Source of Truth), garantizar cero fuga de datos entre inquilinos (*tenant data leak*), y establecer los criterios de aceptación Gherkin que validen el comportamiento de las aplicaciones Backend (FastAPI), Web (Angular) y Móvil (Flutter).

## What Changes
- **Formalización de Autenticación y Seguridad (CU01, CU23, CU24):**
  - Autenticación JWT con inclusión obligatoria del claim `tenant_id` y versión de token (`token_version`).
  - Cierre de sesión seguro (CU24) invalidando el par de tokens mediante incremento de versión (`token_version`) y blacklist.
  - Recuperación de acceso (CU23) mediante códigos de 6 dígitos derivados de HMAC-SHA256 con ventana de tiempo de 30 minutos, límite de tasa (5 intentos máximos y bloqueo temporal de 15 minutos) y respuestas genéricas de seguridad para prevenir enumeración de correos.
- **Formalización de Usuarios y Roles RBAC (CU02, CU26):**
  - CRUD de cuentas de usuarios administrativos y asistenciales con unicidad compuesta `UNIQUE(tenant_id, correo)`.
  - Control de estados (`activo`, `inactivo`) y baja lógica.
  - Matriz de control de acceso basada en roles (RBAC: Administrador, Médico, Recepción, Paciente) y permisos por tenant.
- **Formalización de Gestión de Médicos y Especialidades (CU04):**
  - CRUD de perfiles médicos vinculados 1:1 a cuentas de usuario dentro del tenant.
  - Gestión de matrícula profesional (número de colegiado), biografía, experiencia y foto.
  - Asignación flexible de especialidades médicas con bandera de especialidad principal y catálogo general.
- **Contratos de API REST Multitenant:**
  - Creación de contratos OpenAPI/RESTful limpios para `auth.md`, `users.md` y `doctors.md` con soporte de headers `Authorization: Bearer <token>` y `X-Tenant-ID: <UUID>`.

## Capabilities

### New Capabilities
- `auth-and-access`: Autenticación de usuarios vía JWT, cierre de sesión seguro con revocación de tokens, y recuperación de contraseñas mediante códigos temporales HMAC-SHA256 bajo contexto multitenant (CU01, CU23, CU24).
- `user-and-roles-management`: Administración integral de usuarios internos, estados de cuenta, roles del sistema y matriz de permisos RBAC aislados por `tenant_id` (CU02, CU26).
- `doctor-management`: Gestión de perfiles profesionales médicos, credenciales/matrícula, catálogo de especialidades y asignación por inquilino (CU04).

### Modified Capabilities
*(Ninguna capability previa es modificada; se formaliza la línea base de Sprint 0)*

## Impact
- **Backend (FastAPI):**
  - Módulos afectados: `app/modules/auth/`, `app/modules/users/`, `app/modules/roles/`, `app/modules/medicos/`, `app/core/security.py`.
  - Inyección de dependencias de tenant en endpoints de login, listados de usuarios, asignación de roles y filtros de médicos.
- **Base de Datos (PostgreSQL Neon):**
  - Esquema compartido con `tenant_id: UUID` en tablas `usuarios`, `roles`, `permisos`, `medicos`, `especialidades` y tablas asociativas.
  - Claves únicas compuestas: `UNIQUE(tenant_id, correo)` y `UNIQUE(tenant_id, matricula)`.
- **Frontend Web (Angular):**
  - Flujo de login con almacenamiento del token y selección de tenant.
  - Módulos de administración de usuarios, roles y médicos con Guards e Interceptores HTTP (`X-Tenant-ID`).
- **Frontend Móvil (Flutter):**
  - Pantallas de autenticación, logout y recuperación de contraseña consumiendo contratos formalizados.
- **Contratos de API:**
  - Nuevos contratos `openspec/contracts/auth.md`, `openspec/contracts/users.md` y `openspec/contracts/doctors.md`.
