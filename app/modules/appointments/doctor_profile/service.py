from datetime import datetime, timezone
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload
from app.modules.auth.models import Rol, Usuario
from app.modules.appointments.models import Especialidad, Medico, MedicoEspecialidad
from app.modules.appointments.doctor_entity_links.compat import (
    cu29_tables_available,
)
from app.modules.appointments.doctor_entity_links.models import (
    VinculacionMedicoEntidad,
    VinculacionMedicoEspecialidad,
    VinculacionMedicoRol,
)
from app.modules.appointments.doctor_profile.schemas import (
    AsignacionEspecialidad,
    EspecialidadCreate,
    EspecialidadUpdate,
    MedicoCreate,
    MedicoUpdate,
)

ESTADOS_VALIDOS = ("activo", "inactivo")


def _medico_en_tenant(tenant_id: int):
    """Incluye perfiles heredados sin id_clinica solo durante la transición.

    El join con ``Usuario.id_clinica`` siempre acompaña este criterio; por lo
    tanto un perfil heredado no puede cruzar clínicas. La migración CU04 llena
    la columna y los perfiles nuevos se crean siempre con id_clinica.
    """
    return or_(Medico.id_clinica == tenant_id, Medico.id_clinica.is_(None))


def _get_especialidades_por_ids(db: Session, ids: List[int]) -> List[Especialidad]:
    if len(set(ids)) != len(ids):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La lista de especialidades contiene ids duplicados",
        )
    encontradas = db.query(Especialidad).filter(Especialidad.id_especialidad.in_(ids)).all()
    if len(encontradas) != len(set(ids)):
        faltantes = set(ids) - {e.id_especialidad for e in encontradas}
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Especialidades no encontradas: {sorted(faltantes)}",
        )
    inactivas = [e.nombre for e in encontradas if e.estado != "activo"]
    if inactivas:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Especialidades inactivas: {inactivas}",
        )
    return encontradas


def _vinculo_tenant(db: Session, id_usuario: int, tenant_id: Optional[int]):
    """Vínculo CU29 del usuario con la entidad (None si no existe)."""
    if tenant_id is None or not cu29_tables_available(db):
        return None
    return db.execute(
        select(VinculacionMedicoEntidad).where(
            VinculacionMedicoEntidad.id_usuario == id_usuario,
            VinculacionMedicoEntidad.id_clinica == tenant_id,
        )
    ).scalar_one_or_none()


def _asegurar_rol_principal(db: Session, vinculo: VinculacionMedicoEntidad) -> None:
    existente = db.execute(
        select(VinculacionMedicoRol).where(
            VinculacionMedicoRol.id_vinculacion == vinculo.id_vinculacion
        )
    ).scalars().first()
    if existente is not None:
        return
    usuario = db.get(Usuario, vinculo.id_usuario)
    rol = None
    if usuario is not None and usuario.id_rol is not None:
        rol = db.get(Rol, usuario.id_rol)
    if rol is None:
        rol = db.execute(
            select(Rol).where(Rol.nombre.ilike("MEDICO"))
        ).scalars().first()
    if rol is not None:
        db.add(
            VinculacionMedicoRol(
                id_vinculacion=vinculo.id_vinculacion,
                id_rol=rol.id_rol,
                es_principal=True,
            )
        )


def _completar_vinculo_al_crear_perfil(
    db: Session, medico: Medico, tenant_id: int
) -> None:
    """Completa id_medico y conserva la compatibilidad CU04 ↔ CU29."""
    if not cu29_tables_available(db):
        return
    vinculo = _vinculo_tenant(db, medico.id_usuario, tenant_id)
    if vinculo is None:
        # Compatibilidad transitoria: un perfil creado directamente por CU04
        # mantiene la participación que antes representaba Medico.id_clinica.
        vinculo = VinculacionMedicoEntidad(
            id_clinica=tenant_id,
            id_usuario=medico.id_usuario,
            id_medico=medico.id_medico,
            estado="ACTIVO",
            invitado_por=medico.id_usuario,
            respondido_en=datetime.now(timezone.utc),
            usuario_estado=medico.id_usuario,
        )
        db.add(vinculo)
        db.flush()
    elif vinculo.id_medico is None:
        vinculo.id_medico = medico.id_medico
    _asegurar_rol_principal(db, vinculo)

    tiene_especialidades = db.execute(
        select(VinculacionMedicoEspecialidad.id_especialidad).where(
            VinculacionMedicoEspecialidad.id_vinculacion == vinculo.id_vinculacion
        )
    ).first()
    if tiene_especialidades is None:
        for asignacion in medico.especialidades:
            db.add(
                VinculacionMedicoEspecialidad(
                    id_vinculacion=vinculo.id_vinculacion,
                    id_especialidad=asignacion.id_especialidad,
                    es_principal=bool(asignacion.es_principal),
                )
            )


def _sincronizar_especialidad_vinculo(
    db: Session,
    medico: Medico,
    id_especialidad: int,
    es_principal: bool,
    eliminar: bool = False,
) -> None:
    vinculo = _vinculo_tenant(db, medico.id_usuario, medico.id_clinica)
    if vinculo is None:
        return
    if eliminar:
        asignacion = db.execute(
            select(VinculacionMedicoEspecialidad).where(
                VinculacionMedicoEspecialidad.id_vinculacion == vinculo.id_vinculacion,
                VinculacionMedicoEspecialidad.id_especialidad == id_especialidad,
            )
        ).scalar_one_or_none()
        if asignacion is not None:
            db.delete(asignacion)
        return
    asignacion = db.execute(
        select(VinculacionMedicoEspecialidad).where(
            VinculacionMedicoEspecialidad.id_vinculacion == vinculo.id_vinculacion,
            VinculacionMedicoEspecialidad.id_especialidad == id_especialidad,
        )
    ).scalar_one_or_none()
    if asignacion is None:
        asignacion = VinculacionMedicoEspecialidad(
            id_vinculacion=vinculo.id_vinculacion,
            id_especialidad=id_especialidad,
            es_principal=es_principal,
        )
        db.add(asignacion)
    if es_principal:
        for otra in db.execute(
            select(VinculacionMedicoEspecialidad).where(
                VinculacionMedicoEspecialidad.id_vinculacion == vinculo.id_vinculacion,
                VinculacionMedicoEspecialidad.id_especialidad != id_especialidad,
            )
        ).scalars().all():
            otra.es_principal = False
        asignacion.es_principal = True


def _cargar_relaciones(query):
    return query.options(
        joinedload(Medico.usuario),
        joinedload(Medico.especialidades).joinedload(MedicoEspecialidad.especialidad),
    )


def crear_medico(db: Session, medico_data: MedicoCreate, current_tenant_id: Optional[int] = None) -> Medico:
    if current_tenant_id is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Se requiere una clínica asociada")
    usuario = db.query(Usuario).filter(Usuario.id_usuario == medico_data.id_usuario).first()
    if not usuario:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Usuario con id {medico_data.id_usuario} no encontrado",
        )
    vinculo = _vinculo_tenant(db, usuario.id_usuario, current_tenant_id)
    if (
        current_tenant_id is not None
        and usuario.id_clinica != current_tenant_id
        and vinculo is None
    ):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El usuario no pertenece a la clínica actual",
        )
    if usuario.estado.lower() != "activo":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El usuario está inactivo o suspendido; no puede tener perfil médico",
        )

    existente = db.query(Medico).filter(Medico.id_usuario == medico_data.id_usuario).first()
    if existente:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El usuario ya tiene un perfil médico asociado (relación 1:1)",
        )

    matricula_duplicada = (
        db.query(Medico)
        .filter(Medico.matricula_profesional == medico_data.matricula_profesional)
        .first()
    )
    if matricula_duplicada:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya existe un médico registrado con esta matrícula profesional",
        )

    especialidades: List[Especialidad] = []
    if medico_data.especialidades:
        especialidades = _get_especialidades_por_ids(db, medico_data.especialidades)

    nuevo_medico = Medico(
        id_usuario=medico_data.id_usuario,
        id_clinica=current_tenant_id,
        matricula_profesional=medico_data.matricula_profesional,
        descripcion_profesional=medico_data.descripcion_profesional,
        experiencia=medico_data.experiencia,
        foto_perfil=medico_data.foto_perfil,
        estado="activo",
    )

    for idx, esp in enumerate(especialidades):
        nuevo_medico.especialidades.append(
            MedicoEspecialidad(
                id_especialidad=esp.id_especialidad,
                es_principal=(idx == 0),
            )
        )

    db.add(nuevo_medico)
    try:
        db.flush()
        _completar_vinculo_al_crear_perfil(db, nuevo_medico, current_tenant_id)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya existe un médico registrado con esta matrícula profesional",
        )
    db.refresh(nuevo_medico)
    return nuevo_medico


def listar_medicos(
    db: Session,
    nombre: Optional[str] = None,
    id_especialidad: Optional[int] = None,
    estado: Optional[str] = None,
    skip: int = 0,
    limit: int = 20,
    current_tenant_id: Optional[int] = None,
) -> Tuple[int, List[Medico]]:
    query = db.query(Medico)
    usuario_unido = False

    if current_tenant_id is not None:
        if cu29_tables_available(db):
            query = query.join(
                VinculacionMedicoEntidad,
                VinculacionMedicoEntidad.id_usuario == Medico.id_usuario,
            ).filter(VinculacionMedicoEntidad.id_clinica == current_tenant_id)
        else:
            query = query.join(Usuario, Usuario.id_usuario == Medico.id_usuario).filter(
                _medico_en_tenant(current_tenant_id),
                Usuario.id_clinica == current_tenant_id,
            )
            usuario_unido = True

    if estado is not None:
        query = query.filter(Medico.estado == estado)
    else:
        query = query.filter(Medico.estado == "activo")

    if nombre:
        if not usuario_unido:
            query = query.join(Usuario, Usuario.id_usuario == Medico.id_usuario)
        query = query.filter(
            (Usuario.nombres.ilike(f"%{nombre}%"))
            | (Usuario.apellidos.ilike(f"%{nombre}%"))
            | (Usuario.correo.ilike(f"%{nombre}%"))
        )

    if id_especialidad is not None:
        query = query.join(MedicoEspecialidad).filter(
            MedicoEspecialidad.id_especialidad == id_especialidad
        )

    query = query.distinct()
    total = query.count()
    items = (
        _cargar_relaciones(query)
        .order_by(Medico.id_medico)
        .offset(skip)
        .limit(limit)
        .all()
    )
    return total, items


def obtener_medico(db: Session, id_medico: int, current_tenant_id: Optional[int] = None) -> Medico:
    query = _cargar_relaciones(db.query(Medico)).filter(Medico.id_medico == id_medico)
    if current_tenant_id is not None:
        if cu29_tables_available(db):
            query = query.join(
                VinculacionMedicoEntidad,
                VinculacionMedicoEntidad.id_usuario == Medico.id_usuario,
            ).filter(VinculacionMedicoEntidad.id_clinica == current_tenant_id)
        else:
            query = query.join(Usuario).filter(
                _medico_en_tenant(current_tenant_id),
                Usuario.id_clinica == current_tenant_id,
            )
    medico = query.first()
    if not medico:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Médico con id {id_medico} no encontrado",
        )
    return medico


def obtener_medico_por_usuario(db: Session, id_usuario: int, current_tenant_id: Optional[int] = None) -> Medico:
    query = _cargar_relaciones(db.query(Medico)).filter(Medico.id_usuario == id_usuario)
    if current_tenant_id is not None:
        vinculo = _vinculo_tenant(db, id_usuario, current_tenant_id)
        if vinculo is not None:
            query = query.join(
                VinculacionMedicoEntidad,
                VinculacionMedicoEntidad.id_usuario == Medico.id_usuario,
            ).filter(VinculacionMedicoEntidad.id_clinica == current_tenant_id)
        else:
            # Compatibilidad con perfiles previos a CU29 sin vínculo migrado.
            query = query.join(Usuario).filter(
                _medico_en_tenant(current_tenant_id),
                or_(
                    Usuario.id_clinica == current_tenant_id,
                    Medico.id_clinica == current_tenant_id,
                ),
            )
    medico = query.first()
    if not medico:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El usuario autenticado no tiene perfil médico asociado",
        )
    return medico


def actualizar_medico(db: Session, id_medico: int, datos: MedicoUpdate, current_tenant_id: Optional[int] = None) -> Medico:
    medico = obtener_medico(db, id_medico, current_tenant_id)

    if datos.matricula_profesional and datos.matricula_profesional != medico.matricula_profesional:
        duplicada = (
            db.query(Medico)
            .filter(
                Medico.matricula_profesional == datos.matricula_profesional,
                Medico.id_medico != id_medico,
            )
            .first()
        )
        if duplicada:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Ya existe un médico registrado con esta matrícula profesional",
            )

    cambios = datos.model_dump(exclude_unset=True)
    for campo, valor in cambios.items():
        setattr(medico, campo, valor)

    db.commit()
    db.refresh(medico)
    return medico


def cambiar_estado_medico(db: Session, id_medico: int, nuevo_estado: str, current_tenant_id: Optional[int] = None) -> Medico:
    medico = obtener_medico(db, id_medico, current_tenant_id)
    medico.estado = nuevo_estado
    db.commit()
    db.refresh(medico)
    return medico


def asignar_especialidad(db: Session, id_medico: int, asignacion: AsignacionEspecialidad, current_tenant_id: Optional[int] = None) -> Medico:
    medico = obtener_medico(db, id_medico, current_tenant_id)

    especialidad = (
        db.query(Especialidad)
        .filter(Especialidad.id_especialidad == asignacion.id_especialidad)
        .first()
    )
    if not especialidad:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Especialidad con id {asignacion.id_especialidad} no encontrada",
        )
    if especialidad.estado != "activo":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"La especialidad '{especialidad.nombre}' está inactiva",
        )

    ya_asignada = (
        db.query(MedicoEspecialidad)
        .filter(
            MedicoEspecialidad.id_medico == id_medico,
            MedicoEspecialidad.id_especialidad == asignacion.id_especialidad,
        )
        .first()
    )
    if ya_asignada:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"El médico ya tiene asignada la especialidad '{especialidad.nombre}'",
        )

    if asignacion.es_principal:
        db.query(MedicoEspecialidad).filter(
            MedicoEspecialidad.id_medico == id_medico,
            MedicoEspecialidad.es_principal.is_(True),
        ).update({"es_principal": False}, synchronize_session=False)

    medico.especialidades.append(
        MedicoEspecialidad(
            id_especialidad=asignacion.id_especialidad,
            es_principal=asignacion.es_principal,
        )
    )
    _sincronizar_especialidad_vinculo(
        db,
        medico,
        asignacion.id_especialidad,
        asignacion.es_principal,
    )
    db.commit()
    db.refresh(medico)
    return medico


def quitar_especialidad(db: Session, id_medico: int, id_especialidad: int, current_tenant_id: Optional[int] = None) -> Medico:
    medico = obtener_medico(db, id_medico, current_tenant_id)
    asociacion = (
        db.query(MedicoEspecialidad)
        .filter(
            MedicoEspecialidad.id_medico == id_medico,
            MedicoEspecialidad.id_especialidad == id_especialidad,
        )
        .first()
    )
    if not asociacion:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El médico no tiene asignada esa especialidad",
        )

    _sincronizar_especialidad_vinculo(
        db, medico, id_especialidad, False, eliminar=True
    )
    db.delete(asociacion)
    db.commit()
    db.refresh(medico)
    return medico


def listar_especialidades(db: Session, solo_activas: bool = True) -> List[Especialidad]:
    query = db.query(Especialidad)
    if solo_activas:
        query = query.filter(Especialidad.estado == "activo")
    return query.order_by(Especialidad.nombre).all()


def crear_especialidad(db: Session, datos: EspecialidadCreate) -> Especialidad:
    existente = (
        db.query(Especialidad).filter(Especialidad.nombre.ilike(datos.nombre.strip())).first()
    )
    if existente:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"La especialidad '{datos.nombre}' ya existe",
        )
    nueva = Especialidad(
        nombre=datos.nombre.strip(),
        descripcion=datos.descripcion,
        estado="activo",
    )
    db.add(nueva)
    db.commit()
    db.refresh(nueva)
    return nueva


def actualizar_especialidad(db: Session, id_especialidad: int, datos: EspecialidadUpdate) -> Especialidad:
    especialidad = db.query(Especialidad).filter(Especialidad.id_especialidad == id_especialidad).first()
    if not especialidad:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Especialidad con id {id_especialidad} no encontrada",
        )

    cambios = datos.model_dump(exclude_unset=True)
    if "nombre" in cambios and cambios["nombre"]:
        duplicada = (
            db.query(Especialidad)
            .filter(
                Especialidad.nombre.ilike(cambios["nombre"].strip()),
                Especialidad.id_especialidad != id_especialidad,
            )
            .first()
        )
        if duplicada:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"La especialidad '{cambios['nombre']}' ya existe",
            )

    for campo, valor in cambios.items():
        setattr(especialidad, campo, valor)

    db.commit()
    db.refresh(especialidad)
    return especialidad


def eliminar_especialidad(db: Session, id_especialidad: int) -> None:
    especialidad = db.query(Especialidad).filter(Especialidad.id_especialidad == id_especialidad).first()
    if not especialidad:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Especialidad con id {id_especialidad} no encontrada",
        )

    asignaciones = (
        db.query(MedicoEspecialidad)
        .filter(MedicoEspecialidad.id_especialidad == id_especialidad)
        .count()
    )
    asignaciones_vinculo = 0
    if cu29_tables_available(db):
        asignaciones_vinculo = db.scalar(
            select(func.count()).select_from(VinculacionMedicoEspecialidad).where(
                VinculacionMedicoEspecialidad.id_especialidad == id_especialidad
            )
        ) or 0
    if asignaciones > 0 or (asignaciones_vinculo or 0) > 0:
        total = asignaciones + int(asignaciones_vinculo or 0)
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"No se puede eliminar: {total} médico(s) tienen asignada esta especialidad",
        )

    db.delete(especialidad)
    db.commit()
