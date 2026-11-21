from io import BytesIO
from uuid import uuid4

from fastapi import HTTPException
from PIL import Image, UnidentifiedImageError
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError

from app.core.audit import registrar_auditoria
from app.modules.auth.models import Clinica, Usuario
from app.modules.appointments.models import ServicioMedico
from app.modules.tenants.models import Sede, HorarioSede, TemaAdministrador
from app.modules.medical_records.clinical_documents.storage import DocumentStorage

MAX_LOGO = 2 * 1024 * 1024
COLORES_PREDETERMINADOS = {"principal": "#003667", "secundario": "#006B5F"}


def tema_personal(db, user):
    tema = db.get(TemaAdministrador, (user.id_usuario, user.id_clinica))
    if tema is None:
        return None
    return {"principal": tema.color_principal, "secundario": tema.color_secundario}


def identidad(clinica, tema=None):
    return {**(tema or COLORES_PREDETERMINADOS),
            "logo": clinica.logo if clinica.logo and clinica.logo.startswith(f"marcas/{clinica.id_clinica}/") else None}


def consultar(db, user):
    cid = user.id_clinica
    clinica = db.get(Clinica, cid)
    sedes = select(Sede.id, Sede.nombre, Sede.ubicacion, Sede.activa).where(Sede.id_clinica == cid).order_by(Sede.id)
    s = ServicioMedico
    servicios = select(s.id_servicio.label("id"), s.nombre, s.modalidad, s.costo, s.estado,
                       s.hora_inicio, s.hora_fin, s.duracion_minutos).where(s.id_clinica == cid).order_by(s.id_servicio)
    h = HorarioSede
    horarios = select(h.id_sede, h.dia, h.apertura, h.cierre).join(Sede).where(Sede.id_clinica == cid).order_by(h.id_sede, h.dia, h.apertura)
    return {"identidad": identidad(clinica, tema_personal(db, user)), "direccion": clinica.direccion_acceso,
            "sedes": db.execute(sedes).mappings().all(),
            "servicios": [dict(row, costo=str(row.costo)) for row in db.execute(servicios).mappings()],
            "horarios": db.execute(horarios).mappings().all()}


def guardar(db, user, registro, accion):
    try:
        db.add(registro)
        db.flush()
        registrar_auditoria(db, id_clinica=user.id_clinica, id_usuario=user.id_usuario,
                            tabla_afectada=registro.__tablename__, registro_id=registro.__mapper__.primary_key_from_instance(registro)[0],
                            accion=accion)
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(409, "El registro entra en conflicto con datos existentes") from exc
    except Exception:
        db.rollback()
        raise
    return {"mensaje": "Cambios guardados"}


def propio(db, user, modelo, clave):
    pk = modelo.__mapper__.primary_key[0]
    registro = db.scalar(
        select(modelo).where(pk == clave, modelo.id_clinica == user.id_clinica)
        .with_for_update(of=modelo).execution_options(populate_existing=True)
    )
    if registro is None:
        raise HTTPException(404, "Registro no encontrado")
    return registro


def catalogo(db, user, modelo, datos, clave=None):
    registro = modelo(id_clinica=user.id_clinica) if clave is None else propio(db, user, modelo, clave)
    for nombre, valor in datos.model_dump().items():
        setattr(registro, nombre, valor)
    return guardar(db, user, registro, "CONFIGURAR")


def horarios_dia(db, user, sede_id, dia, datos):
    # Todas las sustituciones y bajas toman el mismo bloqueo, incluso para un día vacío.
    sede = propio(db, user, Sede, sede_id)
    if not sede.activa:
        raise HTTPException(409, "La sede está inactiva")
    db.execute(delete(HorarioSede).where(HorarioSede.id_sede == sede.id, HorarioSede.dia == dia))
    db.add_all([HorarioSede(id_sede=sede.id, dia=dia, **i.model_dump()) for i in datos.intervalos])
    return guardar(db, user, sede, "CONFIGURAR_HORARIO")


def formato_logo(content):
    if len(content) > MAX_LOGO:
        raise HTTPException(422, "El logo supera 2 MB")
    try:
        with Image.open(BytesIO(content), formats=["PNG", "JPEG"]) as image:
            fmt = image.format
            if image.width * image.height > 16000000:
                raise ValueError("Dimensiones excesivas")
            image.verify()
        with Image.open(BytesIO(content)) as image:
            image.load()
    except (OSError, ValueError, SyntaxError, Image.DecompressionBombError, UnidentifiedImageError) as exc:
        raise HTTPException(422, "Seleccione una imagen PNG/JPEG válida de hasta 16 megapíxeles") from exc
    return "png" if fmt == "PNG" else "jpeg"


def guardar_logo(db, user, content):
    extension = formato_logo(content)
    clinica = propio(db, user, Clinica, user.id_clinica)
    anterior = identidad(clinica)["logo"]
    key = f"marcas/{clinica.id_clinica}/{uuid4().hex}.{extension}"
    storage = DocumentStorage()
    storage.write(key, content, f"image/{extension}")
    clinica.logo = key
    try:
        result = guardar(db, user, clinica, "CAMBIAR_LOGO")
    except Exception:
        storage.delete(key)
        raise
    if anterior:
        storage.delete(anterior)
    return result


def cambiar_colores(db, user, datos):
    # Serializa el alta inicial y las actualizaciones para este administrador.
    propio(db, user, Usuario, user.id_usuario)
    tema = db.get(TemaAdministrador, (user.id_usuario, user.id_clinica))
    if tema is None:
        tema = TemaAdministrador(id_usuario=user.id_usuario, id_clinica=user.id_clinica)
    tema.color_principal = datos.principal.upper()
    tema.color_secundario = datos.secundario.upper()
    return guardar(db, user, tema, "CAMBIAR_COLORES")


def registrar_direccion(db, user, datos):
    clinica = propio(db, user, Clinica, user.id_clinica)
    clinica.direccion_acceso = datos.valor
    return guardar(db, user, clinica, "REGISTRAR_DIRECCION")


def desactivar_sede(db, user, clave):
    registro = propio(db, user, Sede, clave)
    registro.activa = False
    return guardar(db, user, registro, "DESACTIVAR")


def desactivar_servicio(db, user, clave):
    registro = propio(db, user, ServicioMedico, clave)
    registro.estado = "inactivo"
    return guardar(db, user, registro, "DESACTIVAR")


def leer_logo(clinica):
    key = identidad(clinica)["logo"]
    data = DocumentStorage().read(key) if key else None
    if not data:
        raise HTTPException(404, "Logo no disponible")
    return data, "image/png" if key.endswith(".png") else "image/jpeg"
