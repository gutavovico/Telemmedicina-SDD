---
name: angular-frontend-standards
description: Estándares de desarrollo para el frontend web en Angular (TypeScript). Standalone Components, Signals, Reactive Forms, consumo tipado de endpoints desde openspec/contracts/ e interceptores multitenant (X-Tenant-ID y Bearer JWT).
---

# Angular Frontend Standards - Portal Web Multitenant

Este estándar define los lineamientos de arquitectura, patrones reactivos y comunicación HTTP para el desarrollo del portal web administrativo y clínico implementado en **Angular (TypeScript)** y estilizado con **Tailwind CSS**.

---

## 1. Arquitectura Angular Moderna

### 1.1 Standalone Components por Defecto
- No se utilizan `NgModule` tradicionales. Todos los componentes, directivas y pipes deben declararse como `standalone: true`:
```typescript
@Component({
  selector: 'app-patient-list',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterModule, LucideAngularModule],
  templateUrl: './patient-list.component.html',
  styleUrls: ['./patient-list.component.css']
})
export class PatientListComponent { ... }
```

### 1.2 Organización Modular por Dominio (`features/`)
```
frontend_Telemedicina/
├── src/
│   ├── app/
│   │   ├── core/                      # Singleton: interceptores, guards, servicios de tenant/auth
│   │   │   ├── interceptors/          # auth.interceptor.ts, tenant.interceptor.ts
│   │   │   ├── guards/                # auth.guard.ts, tenant.guard.ts, role.guard.ts
│   │   │   └── services/              # auth.service.ts, tenant-context.service.ts
│   │   ├── shared/                    # UI Reutilizable: botones, modales, alertas, paginadores
│   │   └── features/                  # Módulos por dominio
│   │       ├── medical-records/       # Dominio de expedientes y pacientes
│   │       │   ├── patients/          # Caso de uso: gestión de pacientes
│   │       │   │   ├── components/    # patient-table, patient-filter
│   │       │   │   ├── pages/         # patient-list-page, patient-form-page
│   │       │   │   ├── models/        # patient.model.ts (alineados a openspec/contracts/)
│   │       │   │   └── services/      # patient.service.ts
│   │       └── auth/                  # Login, selección de clínica/tenant
│   └── styles.css
```

---

## 2. Reactividad con Signals

- **Estado con Signals:** Utilizar `signal()`, `computed()` y `effect()` para la gestión de estado de componentes y vistas reactivas en lugar de depender excesivamente de `BehaviorSubject`:
```typescript
@Component({ ... })
export class PatientListComponent implements OnInit {
  private patientService = inject(PatientService);

  // Signals de estado
  patients = signal<PacienteSummary[]>([]);
  totalPatients = signal<number>(0);
  isLoading = signal<boolean>(false);
  currentPage = signal<number>(1);
  pageSize = signal<number>(10);
  searchQuery = signal<string>('');

  // Signal computado para paginación
  totalPages = computed(() => Math.ceil(this.totalPatients() / this.pageSize()));

  async loadPatients(): Promise<void> {
    this.isLoading.set(true);
    try {
      const response = await firstValueFrom(
        this.patientService.getPatients({
          page: this.currentPage(),
          pageSize: this.pageSize(),
          query: this.searchQuery()
        })
      );
      this.patients.set(response.items);
      this.totalPatients.set(response.total);
    } catch (error) {
      // Manejo de error
    } finally {
      this.isLoading.set(false);
    }
  }
}
```

---

## 3. Formularios Reactivos Fuertemente Tipados

- Utilizar **Reactive Forms** fuertemente tipados (`FormGroup`, `FormControl`, `NonNullableFormBuilder`):
- Los validadores deben reflejar exactamente las restricciones estipuladas en `openspec/specs/` y `openspec/contracts/`:
```typescript
interface PatientForm {
  nombres: FormControl<string>;
  apellidos: FormControl<string>;
  ci: FormControl<string>;
  complemento: FormControl<string>;
  fechaNacimiento: FormControl<string>;
  genero: FormControl<'M' | 'F' | 'OTRO'>;
  telefono: FormControl<string>;
  correo: FormControl<string | null>;
  tipoSangre: FormControl<string | null>;
}

@Component({ ... })
export class PatientFormComponent {
  private fb = inject(NonNullableFormBuilder);

  patientForm = this.fb.group<PatientForm>({
    nombres: this.fb.control('', [Validators.required, Validators.maxLength(100)]),
    apellidos: this.fb.control('', [Validators.required, Validators.maxLength(100)]),
    ci: this.fb.control('', [Validators.required, Validators.maxLength(20)]),
    complemento: this.fb.control('', [Validators.maxLength(10)]),
    fechaNacimiento: this.fb.control('', [Validators.required]),
    genero: this.fb.control('M', [Validators.required]),
    telefono: this.fb.control('', [Validators.required, Validators.maxLength(20)]),
    correo: this.fb.control(null, [Validators.email]),
    tipoSangre: this.fb.control(null)
  });
}
```

---

## 4. Consumo Tipado de Endpoints desde `openspec/contracts/`

- **Prohibido el uso de `any`:** Cada llamada HTTP debe consumir modelos de datos de entrada y salida rigurosamente tipados derivados directamente de los contratos de OpenSpec (`openspec/contracts/*.md`):
```typescript
// models/patient.model.ts
export interface PacienteCreateRequest {
  id_usuario?: number | null;
  nombres: string;
  apellidos: string;
  ci: string;
  complemento?: string;
  fecha_nacimiento: string; // YYYY-MM-DD
  genero: 'M' | 'F' | 'OTRO';
  telefono: string;
  correo?: string | null;
  direccion?: string | null;
  ciudad?: string | null;
  tipo_sangre?: string | null;
  alergias?: string | null;
  antecedentes_patologicos?: string | null;
  contacto_emergencia_nombre?: string | null;
  contacto_emergencia_telefono?: string | null;
  contacto_emergencia_parentesco?: string | null;
  seguro_medico?: string | null;
  numero_seguro?: string | null;
}

export interface PacienteResponse extends PacienteCreateRequest {
  id_paciente: number;
  tenant_id: string; // UUID
  estado: 'ACTIVO' | 'INACTIVO' | 'SUSPENDIDO';
  created_at: string;
  updated_at: string;
}

export interface PacientePaginationResponse {
  items: PacienteResponse[];
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
}
```

---

## 5. Interceptores HTTP Multitenant y Seguridad

Todo el tráfico saliente debe pasar por interceptores funcionales de Angular (`HttpInterceptorFn`):

### 5.1 Interceptor de Tenant y Autenticación
- Inyectar el token JWT en el encabezado `Authorization: Bearer <token>`.
- Inyectar el identificador del inquilino activo en el encabezado `X-Tenant-ID: <UUID>`.
```typescript
// core/interceptors/multitenant.interceptor.ts
export const multitenantInterceptor: HttpInterceptorFn = (req, next) => {
  const authService = inject(AuthService);
  const tenantService = inject(TenantContextService);

  const token = authService.getAccessToken();
  const currentTenant = tenantService.getCurrentTenant();

  let headers = req.headers;

  if (token) {
    headers = headers.set('Authorization', `Bearer ${token}`);
  }

  if (currentTenant?.id) {
    headers = headers.set('X-Tenant-ID', currentTenant.id);
  }

  const clonedReq = req.clone({ headers });
  return next(clonedReq);
};
```

### 5.2 Manejo Global de Errores Multitenant
- Si el backend responde `404 Not Found` en un recurso de paciente, presentar *"El paciente no existe o no pertenece a su organización"*.
- Si responde `409 Conflict`, mostrar mensaje de conflicto dentro del tenant.
- Si responde `401 Unauthorized` o `403 Forbidden`, redireccionar al selector de clínica/login.
