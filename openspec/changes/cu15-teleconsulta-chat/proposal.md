# Propuesta de Cambio: CU15 Teleconsulta y Chat de Cita Médica (`cu15-teleconsulta-chat`)

## 1. Contexto y Objetivos
Habilitar la vista integrada de teleconsulta del paciente y el canal de mensajería bidireccional segura con el médico especialista asignado para una cita médica específica. 

Siguiendo el enfoque **Client-First**, el diseño de datos, contratos y servicios se desprende fielmente del mockup de interfaz validado por producto:
- **Estandarización de Identificadores:** Se homogenizan todos los IDs a números enteros (`number` en TypeScript, `int` en Python/Pydantic y `int` en Dart/Flutter), alineados con las secuencias primarias de PostgreSQL (`id_cita`, `id_paciente`, `id_medico`, `id_usuario`, `id_mensaje`).
- **Arquitectura de Interfaz:**
  - Barra superior con identidad de clínica ("Hospital San Juan de Dios"), navegación global ("Home", "Mis Citas", "Perfil") y selector/avatar de usuario activo ("carlos perez").
  - Ruta de migas (`mis citas`) y título contextualizado `Consulta: ({patientName})`.
  - Columna izquierda: Card **"Mis Datos"** (con desglose de identificación, proveedor y póliza de seguro) y Card **"Detalles de la Cita"**.
  - Columna derecha unificada: Card **"Perfil del Médico y Chat"** con bloque de presentación médica, separador visual tipo píldora y sub-módulo de chat con cabecera destacada, historial de mensajes y caja de entrada de texto.

---

## 2. Contratos de Datos Unificados (TypeScript)

```typescript
// openspec/contracts/teleconsulta-chat.contract.ts

export interface PatientSummaryDTO {
  idPaciente: number;
  nombreCompleto: string;
  identificacionId: string;       // C.I. o documento oficial (ej. "12345678X")
  inicialesAvatar: string;        // ej. "CP"
  seguroProveedor: string;        // ej. "Sanitas Plus"
  seguroPoliza: string;           // ej. "Póliza / Plan Activo" o "Sanitas Plus"
}

export interface AppointmentDetailsDTO {
  idCita: number;
  nombreMedico: string;
  especialidad: string;
  rangoFechas: string;            // ej. "02/09/2024 - 01/02/2024"
  horaTeleconsulta: string;       // ej. "17:00 h"
  modalidad: 'TELEMEDICINA' | 'PRESENCIAL';
  estado: 'PENDIENTE' | 'CONFIRMADA' | 'EN_CURSO' | 'FINALIZADA';
}

export interface DoctorProfileSummaryDTO {
  idMedico: number;
  nombreCompleto: string;
  cargoEtiqueta: string;          // ej. "Su Médico"
  biografia: string;
  fotoUrl: string | null;
  estadoDisponibilidad: 'DISPONIBLE' | 'EN_CONSULTA' | 'DESCONECTADO';
}

export interface ChatMessageDTO {
  idMensaje: number;
  idRemitente: number;
  nombreRemitente: string;
  rolRemitente: 'MEDICO' | 'PACIENTE' | 'SISTEMA';
  contenido: string;
  horaDisplay: string;            // ej. "17:00 h"
  avatarUrl?: string | null;
  esPropio: boolean;
  leido: boolean;
}

export interface SendChatMessageCommand {
  idCita: number;
  contenido: string;
}

// DTO raíz de la vista completa de Teleconsulta / Chat
export interface TeleconsultaViewDTO {
  nombreClinica: string;          // "Hospital San Juan de Dios"
  usuarioActivo: {
    idUsuario: number;
    nombre: string;
    iniciales: string;
  };
  paciente: PatientSummaryDTO;
  cita: AppointmentDetailsDTO;
  medico: DoctorProfileSummaryDTO;
  mensajes: ChatMessageDTO[];
}
```

---

## 3. Esquemas de Datos Backend (Pydantic v2)

```python
# backend_Telemedicina/app/modules/communications/schemas.py
from pydantic import BaseModel, Field
from typing import Optional, List

class PatientSummarySchema(BaseModel):
    id_paciente: int
    nombre_completo: str
    identificacion_id: str
    iniciales_avatar: str
    seguro_proveedor: str
    seguro_poliza: str

class AppointmentDetailsSchema(BaseModel):
    id_cita: int
    nombre_medico: str
    especialidad: str
    rango_fechas: str
    hora_teleconsulta: str
    modalidad: str
    estado: str

class DoctorProfileSummarySchema(BaseModel):
    id_medico: int
    nombre_completo: str
    cargo_etiqueta: str
    biografia: str
    foto_url: Optional[str] = None
    estado_disponibilidad: str

class ChatMessageSchema(BaseModel):
    id_mensaje: int
    id_remitente: int
    nombre_remitente: str
    rol_remitente: str
    contenido: str
    hora_display: str
    avatar_url: Optional[str] = None
    es_propio: bool
    leido: bool

class UsuarioActivoSchema(BaseModel):
    id_usuario: int
    nombre: str
    iniciales: str

class TeleconsultaViewResponse(BaseModel):
    nombre_clinica: str
    usuario_activo: UsuarioActivoSchema
    paciente: PatientSummarySchema
    cita: AppointmentDetailsSchema
    medico: DoctorProfileSummarySchema
    mensajes: List[ChatMessageSchema]

class SendChatMessageRequest(BaseModel):
    contenido: str = Field(..., min_length=1, max_length=2000, description="Texto del mensaje")
```

---

## 4. Endpoints y Estrategia Multitenant
- `GET /api/v1/citas/{id_cita}/teleconsulta`: Retorna `TeleconsultaViewResponse`. Resuelve `tenant_id` (`id_clinica`) desde el token JWT. Si la cita no pertenece a la clínica o el usuario no es participante, retorna `404 Not Found`.
- `POST /api/v1/citas/{id_cita}/chat/mensajes`: Inserta el mensaje validando que la cita esté activa y asociada al usuario autenticado.
- `WebSocket /ws/citas/{id_cita}/chat`: Conexión en tiempo real con autenticación por token para difusión instantánea entre paciente y médico.
