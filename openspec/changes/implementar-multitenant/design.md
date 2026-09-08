# Diseño: Implementar Aislamiento Multitenant

## Arquitectura General

### Patrón de Frontend (Angular 21)

> **Nota**: El frontend usa Angular 21 con:
> - **Signals** para estado reactivo (no BehaviorSubject)
> - **HttpInterceptorFn** (funciones) para interceptores (no clases con @Injectable)
> - **inject()** para inyección de dependencias
> - **withInterceptors()** para registrar interceptores en app.config.ts

```
TenantService (Signals)
    ├── currentTenant = signal<Tenant | null>(null)
    ├── loadTenantContext()
    └── getCurrentTenantId()

tenantInterceptor (HttpInterceptorFn)
    ├── Inyecta header X-Tenant-ID
    └── Lee de TenantService

tenantGuard (CanActivateFn)
    ├── Verifica tenant activo
    └── Redirige si no hay tenant
```

---

## Componentes de Frontend

### 1. TenantService (`src/app/core/services/tenant.service.ts`)

```typescript
import { Injectable, inject, signal, computed } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../../environments/environment';
import { AuthService } from './auth.service';
import { TenantContext } from '../models/tenant.models';

@Injectable({ providedIn: 'root' })
export class TenantService {
  private readonly http = inject(HttpClient);
  private readonly authService = inject(AuthService);
  private readonly apiUrl = environment.apiUrl;

  readonly currentTenant = signal<TenantContext | null>(null);
  readonly clinicaId = computed(() => this.currentTenant()?.clinica_id ?? null);
  readonly clinicaNombre = computed(() => this.currentTenant()?.clinica_nombre ?? '');
  readonly isSuperAdmin = computed(() => this.currentTenant()?.es_super_admin === true);

  loadTenantContext(): void {
    this.http.get<TenantContext>(`${this.apiUrl}/api/v1/tenant/context`).subscribe({
      next: (tenant) => this.currentTenant.set(tenant),
      error: () => {
        const user = this.authService.currentUser();
        if (user?.id_clinica) {
          this.currentTenant.set({
            clinica_id: user.id_clinica,
            clinica_nombre: 'Mi Clínica',
            estado: 'ACTIVO',
            rol: user.rol || 'Administrador',
            es_super_admin: false
          });
        }
      }
    });
  }

  getCurrentTenantId(): number | null {
    return this.clinicaId();
  }

  clearTenant(): void {
    this.currentTenant.set(null);
  }
}
```

### 2. TenantInterceptor (`src/app/core/interceptors/tenant.interceptor.ts`)

```typescript
import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { TenantService } from '../services/tenant.service';

export const tenantInterceptor: HttpInterceptorFn = (req, next) => {
  const tenantService = inject(TenantService);
  const tenantId = tenantService.getCurrentTenantId();

  if (tenantId && !req.url.includes('/public/') && !req.url.includes('/auth/')) {
    const modifiedReq = req.clone({
      setHeaders: { 'X-Tenant-ID': tenantId.toString() }
    });
    return next(modifiedReq);
  }

  return next(req);
};
```

### 3. TenantGuard (`src/app/core/guards/tenant.guard.ts`)

```typescript
import { CanActivateFn } from '@angular/router';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { TenantService } from '../services/tenant.service';

export const tenantGuard: CanActivateFn = (route, state) => {
  const tenantService = inject(TenantService);
  const router = inject(Router);

  if (tenantService.clinicaId()) {
    return true;
  }

  router.navigate(['/login']);
  return false;
};
```

### 4. Modelo TenantContext (`src/app/core/models/tenant.models.ts`)

```typescript
export interface TenantContext {
  clinica_id: number;
  clinica_nombre: string;
  estado: 'ACTIVO' | 'INACTIVO' | 'SUSPENDIDO';
  rol: string;
  es_super_admin?: boolean;
  usuarios_activos?: number;
}

export interface Clinica {
  clinica_id: number;
  nombre: string;
  estado: 'ACTIVO' | 'INACTIVO' | 'SUSPENDIDO';
  usuarios_activos: number;
}
```

### 5. Actualización de `app.config.ts`


---

## Componentes de Backend

### 1. Modelos con Tenant (Ya existentes)

> **Nota**: Los modelos actuales (`Usuario`, `Rol`, `Paciente`, `Auditoria`) ya incluyen `id_clinica` como FK.
> No se requiere crear un `TenantMixin`. La estructura actual es:

```python
# Ejemplo: app/modules/auth/models.py (Usuario)
class Usuario(Base):
    __tablename__ = "usuarios"
    
    id_usuario = Column(BigInteger, primary_key=True, autoincrement=True)
    id_clinica = Column(BigInteger, ForeignKey("clinicas.id_clinica"), nullable=True, index=True)
    # ... otros campos
```

### 2. TenantAwareService (`app/core/services/base_service.py`)

> **Ajuste backend real:** `core/database.py` usa `Session` síncrona (`session.query()`),
> no `AsyncSession`. No existe `self.Model` base; cada servicio declara su modelo.

```python
from sqlalchemy.orm import Session
from app.modules.auth.models import Clinica

class TenantAwareService:
    """Servicio base que filtra automáticamente por tenant (síncrono)."""
    Model = None  # definir en subclase, ej. Usuario

    def __init__(self, db: Session, tenant: Clinica):
        self.db = db
        self.tenant = tenant

    def filter_by_tenant(self, query):
        """Agrega filtro de tenant a cualquier consulta"""
        assert self.Model is not None, "Subclase debe definir Model"
        return query.filter(self.Model.id_clinica == self.tenant.id_clinica)

    def validate_ownership(self, obj) -> bool:
        """Verifica que un objeto pertenezca al tenant actual"""
        return getattr(obj, "id_clinica", None) == self.tenant.id_clinica
```

### 3. Dependencia get_current_tenant (`app/core/dependencies/tenant.py`)

> **Nota**: El claim en el JWT se llama `tenant_id` (no `clinica_id`) para mantener consistencia con el login existente.

```python
# Backend real: síncrono (def, no async), reutiliza get_current_user/get_current_tenant_id.
# OJO: Usuario NO tiene columna es_super_admin; el rol Super Admin se resuelve por
# Rol.nombre in ("ADMIN","ADMINISTRADOR") o id_rol==1 (ver auth/dependencies.py:88-97).
from fastapi import Depends, HTTPException, Header
from typing import Optional
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.modules.auth.models import Clinica, Usuario
from app.modules.auth.dependencies import get_current_user

def get_current_tenant(
    x_tenant_id: Optional[int] = Header(None, alias="X-Tenant-ID"),
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Clinica:
    """
    Resuelve el tenant actual.
    - Usuarios normales: usan id_clinica propio (espejo del claim JWT "tenant_id": str|None).
    - Admin global (id_clinica NULL + rol ADMIN): puede especificar X-Tenant-ID: <int>.
    """
    token_tenant_id = current_user.id_clinica  # ya validado en login/router.py:62
    is_admin = (current_user.id_rol == 1) or (
        current_user.rol and current_user.rol.nombre.upper() in ("ADMIN", "ADMINISTRADOR", "ADMINISTRACION")
    )
    tenant_id = x_tenant_id if (x_tenant_id is not None and is_admin) else token_tenant_id
    if tenant_id is None:
        raise HTTPException(status_code=401, detail="Sin contexto de tenant")
    tenant = db.query(Clinica).filter(Clinica.id_clinica == tenant_id).first()
    if not tenant:
        raise HTTPException(status_code=404, detail="Recurso no encontrado")
    if tenant.estado != "ACTIVO":
        raise HTTPException(status_code=403, detail="Clínica inactiva. Contacte al administrador.")
    return tenant
```

---

## Endpoints de Tenant (Backend)

### GET /api/v1/tenant/context

Retorna el tenant actual del usuario autenticado.

**Request:**
```
GET /api/v1/tenant/context
Authorization: Bearer <token>
```

**Response 200:**
```json
{
  "clinica_id": 1,
  "clinica_nombre": "Hospital San Juan de Dios",
  "rol": "Administrador",
  "estado": "ACTIVO",
  "es_super_admin": false,
  "usuarios_activos": 15
}
```

### GET /api/v1/clinicas (Solo Super Admin)

Lista todos los tenants de la plataforma.

**Request:**
```
GET /api/v1/clinicas?estado=ACTIVO&page=1&per_page=20
Authorization: Bearer <token>
```

**Response 200:**
```json
{
  "total": 5,
  "page": 1,
  "per_page": 20,
  "items": [
    {
      "clinica_id": 1,
      "nombre": "Hospital San Juan de Dios",
      "estado": "ACTIVO",
      "usuarios_activos": 15
    }
  ]
}
```

### PATCH /api/v1/clinicas/{clinica_id}/estado

Actualiza el estado de un tenant (solo Super Admin).

**Request:**
```
PATCH /api/v1/clinicas/1/estado
Authorization: Bearer <token>

{
  "estado": "INACTIVO"
}
```

**Response 200:**
```json
{
  "clinica_id": 1,
  "nombre": "Hospital San Juan de Dios",
  "estado": "INACTIVO",
  "mensaje": "Estado actualizado correctamente"
}
```

---

## Estrategia de Índices

```sql
-- Índices compuestos para consultas eficientes por tenant
CREATE INDEX idx_usuarios_clinica_correo ON usuarios(id_clinica, correo);
CREATE INDEX idx_pacientes_clinica_ci ON pacientes(id_clinica, ci);
CREATE INDEX idx_citas_clinica_fecha ON citas(id_clinica, fecha);
CREATE INDEX idx_auditoria_clinica_fecha ON auditoria(id_clinica, fecha_hora);
```

---

## Manejo de Errores

| Escenario | Código | Mensaje |
|-----------|--------|---------|
| Tenant no encontrado | 404 | "Recurso no encontrado" |
| Tenant inactivo | 403 | "Clínica inactiva. Contacte al administrador." |
| Sin acceso al tenant | 404 | "Recurso no encontrado" |
| Inyección de tenant | 400 | "No se puede modificar el tenant" |

---

## Notas de Implementación

### Backend

1. **Modelos con `id_clinica`**: Los modelos (`Usuario`, `Rol`, `Paciente`, `Auditoria`) ya incluyen `id_clinica: BigInteger FK` (nullable=True salvo `Auditoria`). No se requiere `TenantMixin`. `Medico` NO tiene FK directa (hereda vía `Usuario`).

2. **Claim en JWT**: El `login/router.py:62,140` ya incluye `tenant_id: str(id_clinica)|None` en el payload. El spec antiguo usa `clinica_id` pero el backend usa `tenant_id` — se mantiene `tenant_id` por consistencia. Header `X-Tenant-ID: <int>`.

3. **Unicidades pendientes:** `Usuario.correo unique=True` global y `Paciente UniqueConstraint(ci, complemento)` global deben migrarse a `UNIQUE(id_clinica, correo)` y `UNIQUE(id_clinica, ci, complemento)`. `Auditoria.id_clinica` tiene contradicción modelo (`NOT NULL`) vs `seed_clinica.py:16` (`DROP NOT NULL`).

3. **Super Admin SaaS vs Admin tenant:** `require_super_admin` = `id_clinica IS NULL + (id_rol==1 o Rol.nombre in ADMIN/ADMINISTRADOR)`. Admin tenant opera filtrado; Super Admin opera sin filtro (bitácora/dashboard global, `GET /clinicas`, `X-Tenant-ID`).

4. **Nuevos archivos a crear**:
   - `app/core/dependencies/tenant.py` - `get_current_tenant()` + `require_super_admin()`
   - `app/core/services/base_service.py` - Clase `TenantAwareService` sync
   - `app/modules/clinicas/router.py` - `GET /clinicas`, `PATCH /clinicas/{id}/estado` (Super Admin)
   - `app/modules/public/clinicas/router.py` - `POST /public/clinicas/registrar` (onboarding: clínica + admin inicial)
   - `app/modules/tenant/router.py` - `GET /tenant/context` (`{clinica_id, clinica_nombre, estado, rol, permisos[], es_super_admin}`)

5. **Endpoints nuevos**:
   - `GET /api/v1/tenant/context` - Contexto del tenant actual (fuente de `rol/permisos`, el JWT no los trae)
   - `GET /api/v1/clinicas` - Listar tenants (Super Admin)
   - `PATCH /api/v1/clinicas/{id}/estado` - Actualizar estado de tenant (Super Admin)
   - `POST /api/v1/public/clinicas/registrar` - Onboarding público
   - `GET /auditoria` global (`?clinica_id=`) + `GET /analytics/resumen-global` (solo Super Admin) vs vistas tenant filtradas

### Frontend (teoría `Frontend_Multitenant_SaaS.md`, solo conceptos — sus carpetas/código se ignoran)

1. **Usuario Response**: `UsuarioResponse` ya incluye `id_clinica?: number` y `tenant_id?: string`. JWT solo trae `{sub, tenant_id:str|null, email, token_version}` → `rol/permisos` se obtienen de `GET /me` + `GET /tenant/context` y se normaliza `tenant_id:string` con `parseInt()` a `clinica_id:number`.

2. **Servicios nuevos:** `TenantService` (Signals + `localStorage current_clinica`, SSR `isPlatformBrowser()`), `TokenService` (storage, `decodeToken`, `isExpired/isAboutToExpire`), `PermissionsService` (`hasPermission/hasAny/hasAll`, `isSuperAdmin/isAdminClinica` desde context, no del JWT).

3. **Interceptores (orden):** `authInterceptor` (Bearer + refresh anticipado + `catchError 401→logout+/login`) primero, `tenantInterceptor` (`X-Tenant-ID:<int>`, excluir `/public/, /auth/login, /auth/register, /register, /login, /recuperar`) segundo, con `withInterceptors([authInterceptor, tenantInterceptor])`.

4. **Signals vs BehaviorSubject**: Todo el estado nuevo usa Signals (`signal/computed/inject()` + `HttpInterceptorFn`/`CanActivateFn`), consistente con Angular moderno del repo.

5. **SSR Safety**: Guards y servicios verifican `isPlatformBrowser()` antes de `localStorage`.

6. **Guards:** respetar `authGuard/adminGuard` existentes + `tenantGuard` (hay tenant) + `ClinicaGuard` (`estado==ACTIVO` sino `/clinica-inactiva`) + `PermissionsGuard` (`data.permissions` sino `/sin-permisos`) + `SuperAdminGuard` (`es_super_admin` sino `/dashboard`).

7. **UI + onboarding:** `TenantSelectorComponent` (Super Admin), `Navbar` con `clinica.nombre`, `Dashboard` filtra por permiso, `redirigirSegunRol {Administrador:/dashboard, Médico:/mis-citas, Recepción:/citas, Paciente:/mi-historial}`, `PublicService.registrarClinica()` + ruta pública `/registro-clinica` (`POST /public/clinicas/registrar` → `/login?email=`).

```typescript
import { tenantInterceptor } from './core/interceptors/tenant.interceptor';

export const appConfig: ApplicationConfig = [
  provideBrowserGlobalErrorListeners(),
  provideRouter(routes),
  provideHttpClient(
    withFetch(),
    withInterceptors([authInterceptor, tenantInterceptor])
  ),
  provideClientHydration(withEventReplay())
];
```

### 6. Integración con AuthService

El `AuthService` existente debe inyectar `TenantService` y llamar a `loadTenantContext()` después del login:

```typescript
// En auth.service.ts
login(credentials: LoginRequest, rememberMe: boolean = false): Observable<TokenResponse> {
  return this.http.post<TokenResponse>(`${this.apiUrl}/auth/login`, credentials).pipe(
    tap((response) => {
      this.saveTokens(response.access_token, response.refresh_token, rememberMe);
      this.fetchUserProfile();
      this.tenantService.loadTenantContext();
    })
  );
}

logout(): void {
  this.tenantService.clearTenant();
  // ... resto del código existente
}
```
