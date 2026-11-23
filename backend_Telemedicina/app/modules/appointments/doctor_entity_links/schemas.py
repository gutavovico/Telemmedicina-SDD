"""Contratos Pydantic v2 de CU29 (vinculación médico-entidad)."""
from datetime import datetime
from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field, model_validator


ESTADO_VINCULACION = Literal["INVITADO", "ACTIVO", "SUSPENDIDO", "RECHAZADO", "BAJA"]
ESTADO_ADMINISTRABLE = Literal["ACTIVO", "SUSPENDIDO", "BAJA"]
MODO_VINCULACION = Literal["EXISTENTE", "NUEVO"]
CRITERIO_BUSQUEDA = Literal["correo", "documento_identidad", "matricula_profesional"]


class AsignacionEspecialidadInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_especialidad: int = Field(..., gt=0)
    es_principal: bool = False


class AsignacionesInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    roles: List[int] = Field(..., min_length=1, max_length=100)
    id_rol_principal: int = Field(..., gt=0)
    especialidades: List[AsignacionEspecialidadInput] = Field(default_factory=list, max_length=100)
    sedes: List[int] = Field(default_factory=list, max_length=100)

    @model_validator(mode="after")
    def validar_roles_y_especialidades(self):
        if len(set(self.roles)) != len(self.roles):
            raise ValueError("La lista de roles contiene identificadores duplicados")
        if self.id_rol_principal not in self.roles:
            raise ValueError("id_rol_principal debe pertenecer a roles")
        ids_especialidades = [e.id_especialidad for e in self.especialidades]
        if len(set(ids_especialidades)) != len(ids_especialidades):
            raise ValueError("La lista de especialidades contiene identificadores duplicados")
        if sum(1 for e in self.especialidades if e.es_principal) > 1:
            raise ValueError("Solo una especialidad puede ser principal")
        return self


class UsuarioNuevoInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nombres: str = Field(..., min_length=1, max_length=100)
    apellidos: str = Field(..., min_length=1, max_length=100)
    correo: EmailStr
    telefono: Optional[str] = Field(None, max_length=30)
    documento_identidad: Optional[str] = Field(None, min_length=3, max_length=30)


class VinculacionCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    modo: MODO_VINCULACION
    id_usuario: Optional[int] = Field(None, gt=0)
    usuario: Optional[UsuarioNuevoInput] = None
    asignaciones: AsignacionesInput

    @model_validator(mode="after")
    def validar_modo(self):
        if self.modo == "EXISTENTE":
            if self.id_usuario is None:
                raise ValueError("id_usuario es obligatorio en modo EXISTENTE")
            if self.usuario is not None:
                raise ValueError("usuario no se acepta en modo EXISTENTE")
        else:
            if self.usuario is None:
                raise ValueError("usuario es obligatorio en modo NUEVO")
            if self.id_usuario is not None:
                raise ValueError("id_usuario no se acepta en modo NUEVO")
        return self


class AsignacionesVinculacion(AsignacionesInput):
    row_version: int = Field(..., ge=1)


class VinculacionEstadoUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    estado: ESTADO_ADMINISTRABLE
    motivo: Optional[str] = Field(None, min_length=3, max_length=500)
    row_version: int = Field(..., ge=1)

    @model_validator(mode="after")
    def validar_motivo(self):
        if self.estado in ("SUSPENDIDO", "BAJA") and not self.motivo:
            raise ValueError("motivo es obligatorio para SUSPENDIDO y BAJA")
        return self


class VinculacionRechazo(BaseModel):
    model_config = ConfigDict(extra="forbid")

    motivo: str = Field(..., min_length=3, max_length=500)


class CandidatoVinculacion(BaseModel):
    id_usuario: int
    nombres: str
    apellidos: str
    correo: str
    documento_identidad: Optional[str] = None
    matricula_profesional: Optional[str] = None
    existe_perfil: bool


class RolAsignadoResponse(BaseModel):
    id_rol: int
    nombre: str
    es_principal: bool


class EspecialidadAsignadaResponse(BaseModel):
    id_especialidad: int
    nombre: str
    es_principal: bool


class VinculacionResponse(BaseModel):
    id_vinculacion: int
    id_usuario: int
    id_medico: Optional[int] = None
    estado: str
    nombres: str
    apellidos: str
    correo: str
    telefono: Optional[str] = None
    documento_identidad: Optional[str] = None
    matricula_profesional: Optional[str] = None
    existe_perfil: bool
    roles: List[RolAsignadoResponse] = Field(default_factory=list)
    especialidades: List[EspecialidadAsignadaResponse] = Field(default_factory=list)
    sedes: List[int] = Field(default_factory=list)
    fecha_invitacion: datetime
    respondido_en: Optional[datetime] = None
    fecha_estado: datetime
    motivo_estado: Optional[str] = None
    row_version: int


class VinculacionCreadaResponse(BaseModel):
    id_vinculacion: int
    id_usuario: int
    id_medico: Optional[int] = None
    estado: str


class CredencialTemporalResponse(BaseModel):
    correo: str
    password_temporal: str
    expira_en: datetime


class VinculacionCreateResponse(BaseModel):
    vinculacion: VinculacionCreadaResponse
    perfil_pendiente: bool
    credencial_temporal: Optional[CredencialTemporalResponse] = None


class VinculacionListResponse(BaseModel):
    total: int
    page: int
    per_page: int
    items: List[VinculacionResponse] = Field(default_factory=list)


class EntidadMedicoVinculadaResponse(BaseModel):
    id_clinica: int
    nombre: str


class EntidadesMedicoVinculadasResponse(BaseModel):
    items: List[EntidadMedicoVinculadaResponse] = Field(default_factory=list)


class HistorialVinculacionResponse(BaseModel):
    id_historial: int
    tipo_evento: str
    estado_anterior: Optional[str] = None
    estado_nuevo: Optional[str] = None
    id_usuario_actor: int
    nombre_actor: Optional[str] = None
    motivo: Optional[str] = None
    datos: Dict[str, Any] = Field(default_factory=dict)
    fecha_cambio: datetime


class VinculacionDetalleResponse(BaseModel):
    vinculacion: VinculacionResponse
    historial: List[HistorialVinculacionResponse] = Field(default_factory=list)


class PermisosEfectivosResponse(BaseModel):
    roles: List[str] = Field(default_factory=list)
    rol_principal: Optional[str] = None
    permisos: List[str] = Field(default_factory=list)
