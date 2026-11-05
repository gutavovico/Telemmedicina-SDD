# Propuesta de Cambio: CU08 Consultar y Actualizar Tiempos de Espera — Live Queue (`cu08-live-queue`)

## 1. Contexto y Objetivos

Habilitar la **fila virtual del día** (Live Queue): el paciente consulta su posición y tiempo estimado de espera; el médico o recepción mantiene la fila actualizada ante avance, retrasos, pausas o imprevistos.

**CU08 no es CU07.** CU07 (responsable: Terrazas Padilla Cristhian) gestiona la *lista de espera sin cupos* (`lista_espera`); CU08 gestiona el *orden de atención de citas ya asignadas* (`citas` del día). CU08 vive exclusivamente de `citas` y funciona sin que CU07 exista (ver §6 Interoperabilidad).

Siguiendo el enfoque **Client-First** de CU15, los DTOs se desprenden de las vistas:
- **Paciente (web y móvil):** tarjeta "Mi turno de hoy" (posición, ETA, estado de la cola, aviso de turno próximo).
- **Staff (web agenda + móvil médico):** cola operativa del día por médico (posición por cita, hora, estado operativo, ETA, acciones avanzar / marcar perdida / registrar pausa).

## 2. Reutilización de Tablas (sin DDL nuevo)

No se crea ninguna tabla ni migración. Columnas ya existentes:

| Tabla | Columnas usadas | Rol en CU08 |
|---|---|---|
| `citas` | `id_clinica`, `id_medico`, `id_paciente`, `fecha_cita`, `hora_inicio`, `estado` (VARCHAR libre), `check_in` | Universo de la fila; `check_in` marca llegada |
| `bloqueos_agenda` | `id_medico`, `fecha`, `hora_inicio/fin`, `motivo`, `estado=APROBADO` | Pausas/retrasos/imprevistos de franja |
| `servicios_medicos` | `duracion_minutos` | Duración promedio para el ETA (fallback 20 min si la cita no trae servicio) |
| `notificaciones` | `id_usuario`, `tipo=TURNO_PROXIMO`, `titulo`, `mensaje`, `estado=PENDIENTE` | Aviso de turno próximo |
| `pacientes` / `medicos` / `usuarios` | vínculos `id_usuario`, `id_clinica` | Resolución de actor y tenant |

**Estados operativos** (valores de `citas.estado`, columna VARCHAR sin CHECK, sin migración):
existentes `PENDIENTE`, `CONFIRMADA` + nuevos `EN_CURSO` (siendo atendido), `ATENDIDA` (salió de la fila por atención; el cierre clínico a `COMPLETADA` sigue siendo CU28), `PERDIDA` (perdió su turno). `CANCELADA`/`COMPLETADA`/`ATENDIDA`/`PERDIDA` quedan fuera de la fila.

## 3. Contratos de Datos Unificados (TypeScript)

```typescript
// core/models/live-queue.models.ts (derivado de openspec/contracts/live-queue.md)

export type EstadoCola = 'NORMAL' | 'PAUSADA' | 'DEMORADA' | 'SIN_TURNOS';
export type EstadoOperativoCita = 'PENDIENTE' | 'CONFIRMADA' | 'EN_CURSO' | 'ATENDIDA' | 'PERDIDA' | 'CANCELADA' | 'COMPLETADA';

export interface MiTurnoDTO {
  idCita: number;
  hora: string;                 // "09:30"
  estado: EstadoOperativoCita;
  posicion: number;             // 1 = siendo atendido / siguiente
  etaMinutos: number;           // 0 si es su turno
  delante: number;              // citas por delante
  proximo: boolean;             // posicion <= 2 → mostrar aviso
  estadoCola: EstadoCola;
  mensajeCola: string | null;   // ej. "Atención pausada hasta las 10:15 por imprevisto"
  medicoNombre: string;
  fecha: string;                // "2026-10-04"
}

export interface EntradaColaDTO {
  idCita: number;
  hora: string;
  estado: EstadoOperativoCita;
  posicion: number;
  etaMinutos: number;
  pacienteNombre: string;       // gestión (sin datos clínicos: sin motivo ni notas)
  checkIn: string | null;
}

export interface ColaOperativaDTO {
  idMedico: number;
  medicoNombre: string;
  fecha: string;
  estadoCola: EstadoCola;
  mensajeCola: string | null;
  duracionPromedioMin: number;
  totalPendientes: number;
  entradas: EntradaColaDTO[];
}

export interface RegistrarPausaCommand {
  idMedico: number;
  fecha: string;                // YYYY-MM-DD
  horaInicio: string;           // "HH:MM"
  horaFin: string;              // "HH:MM"
  motivo: string;               // min 3 caracteres
}
```

## 4. Esquemas de Datos Backend (Pydantic v2)

```python
# backend_Telemedicina/app/modules/appointments/live_queue/schemas.py
from pydantic import BaseModel, Field
from typing import Optional

class MiTurnoResponse(BaseModel):
    id_cita: int
    hora: str
    estado: str
    posicion: int
    eta_minutos: int
    delante: int
    proximo: bool
    estado_cola: str
    mensaje_cola: Optional[str] = None
    medico_nombre: str
    fecha: str

class EntradaColaResponse(BaseModel):
    id_cita: int
    hora: str
    estado: str
    posicion: int
    eta_minutos: int
    paciente_nombre: str
    check_in: Optional[str] = None

class ColaOperativaResponse(BaseModel):
    id_medico: int
    medico_nombre: str
    fecha: str
    estado_cola: str
    mensaje_cola: Optional[str] = None
    duracion_promedio_min: int
    total_pendientes: int
    entradas: list[EntradaColaResponse]

class PausaCreate(BaseModel):
    id_medico: int = Field(..., gt=0)
    fecha: str = Field(..., pattern=r"^\d{4}-\d{2}-\d{2}$")
    hora_inicio: str = Field(..., pattern=r"^\d{2}:\d{2}(:\d{2})?$")
    hora_fin: str = Field(..., pattern=r"^\d{2}:\d{2}(:\d{2})?$")
    motivo: str = Field(..., min_length=3, max_length=500)
```

## 5. Endpoints y Estrategia Multitenant

Montaje en `appointments/router.py` (patrón CU15/CU05): `live_queue_router` con `prefix="/cola"`, incluido plano y con `prefix="/api/v1"` → sirve `/cola/*` y `/api/v1/cola/*`. Web y móvil consumen `/api/v1/cola/*`.

- `GET /api/v1/cola/mi-turno` → `MiTurnoResponse`. Solo PACIENTE (su cita pendiente de hoy). Sin cita → `estado_cola=SIN_TURNOS`, `posicion=0`.
- `GET /api/v1/cola?fecha=&id_medico=` → `ColaOperativaDTO`. MEDICO (solo su `id_medico`, 403 ajeno) / RECEPCION (`id_medico` obligatorio, 422 si falta). Sin rol ADMIN de clínica (matriz HU; 403).
- `POST /api/v1/cola/{id_cita}/avanzar` → marca la cita `ATENDIDA`, pone `EN_CURSO` a la siguiente pendiente y crea `Notificacion(TURNO_PROXIMO)` a los pacientes que queden en posición 1–2 (si tienen usuario vinculado). MEDICO/RECEPCION.
- `POST /api/v1/cola/{id_cita}/perdida` → marca `PERDIDA` y avanza la fila igual que avanzar. MEDICO/RECEPCION.
- `POST /api/v1/cola/pausas` (201) → crea `BloqueoAgenda` (`estado=APROBADO`) de franja corta con motivo. MEDICO/RECEPCION.

Tenant: `get_required_tenant_id` obligatorio (precedente CU15) + scope por `join(Usuario).filter(Usuario.id_clinica == tenant)` con tolerancia a `Cita.id_clinica NULL` legado (precedente `communications/service.py`). Cross-tenant → `404`; rol indebido → `403`; paciente que pide cita ajena → `404`.

## 6. Interoperabilidad futura con CU07 (lista de espera)

La cola **solo lee `citas`**; jamás lee `lista_espera`:

1. **Cancelación:** cuando una cita se cancela (flujo CU25 existente), CU08 la excluye y las posiciones restantes se recalculan solas. CU07, cuando exista, ofrecerá ese hueco a su lista en paralelo.
2. **Reasignación CU07:** si CU07 confirma un turno a un paciente en espera, eso crea una `cita` normal (`PENDIENTE/CONFIRMADA`), que aparece automáticamente en la fila de CU08 sin ningún cambio.
3. **Sin acoplamiento:** CU08 no importa, consulta ni modifica `lista_espera`; CU07 no necesita saber de la cola. El contrato entre ambos es la tabla `citas`.
