"""Base de pruebas de CU11: SQLite en memoria, ``get_db`` sobreescrito y datos semilla.

Misma técnica que el resto de la suite (``tests/test_cu12_documentos.py``): ``Base.metadata.create_all``
sobre SQLite con ``StaticPool`` y override de ``get_db``. Sin ``aiosqlite`` ni sesión asíncrona
(excepción CU11 de ``AGENTS.md`` sección 5).
"""
from datetime import date

from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.main import app
from app.modules.auth.models import Clinica, Permiso, Rol, RolPermiso, Usuario
from app.modules.medical_records.laboratory_orders.models import ExamenLaboratorio, OrdenLaboratorio
from app.modules.medical_records.laboratory_results.models import ResultadoLaboratorio  # noqa: F401
from app.modules.medical_records.laboratory_sync.models import (  # noqa: F401
    FuenteLaboratorio,
    SincronizacionLaboratorio,
    SincronizacionLaboratorioItem,
)
from app.modules.medical_records.models import Paciente

PERMISOS_LAB_RESULTS = ("lab_results:create", "lab_results:read", "lab_results:review", "lab_results:sync")
PERMISOS_DOCUMENTS = (
    "documents:read:prescriptions",
    "documents:read:lab_orders",
    "documents:read:lab_results",
    "documents:read:certificates",
    "documents:download",
    "documents:search",
)

# Matriz de CU11 (spec laboratory-results, requisito "Permisos y asignación por rol").
MATRIZ_LAB_RESULTS = {
    "ADMIN": ("lab_results:create", "lab_results:read", "lab_results:review", "lab_results:sync"),
    "MEDICO": ("lab_results:create", "lab_results:read", "lab_results:review"),
    "RECEPCION": ("lab_results:create", "lab_results:read"),
    "PACIENTE": ("lab_results:read",),
}
# Matriz vigente de CU12 (migraciones 004 y 006): RECEPCION no lee resultados de laboratorio.
MATRIZ_DOCUMENTS = {
    "ADMIN": PERMISOS_DOCUMENTS,
    "MEDICO": PERMISOS_DOCUMENTS,
    "RECEPCION": tuple(p for p in PERMISOS_DOCUMENTS if p != "documents:read:lab_results"),
    "PACIENTE": PERMISOS_DOCUMENTS,
}


def build_engine():
    """Motor SQLite en memoria con todo el metadata (incluidas las tablas de CU11)."""
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    _transacciones_explicitas(engine)
    Base.metadata.create_all(engine)
    return engine


def _transacciones_explicitas(engine):
    """Receta de SQLAlchemy para pysqlite: emitir ``BEGIN`` real al abrir la transacción.

    Sin esto el driver no inicia transacción hasta el primer INSERT/UPDATE/DELETE y un ``SAVEPOINT`` posterior
    a un ``SELECT`` queda como transacción más externa: su ``RELEASE`` confirma de inmediato y ya no se puede
    deshacer con el ``rollback`` externo. Con el ``BEGIN`` explícito el SQLite de pruebas se comporta como
    PostgreSQL (los ``SAVEPOINT`` por ítem de la sincronización se anidan de verdad).
    """

    @event.listens_for(engine, "connect")
    def _sin_autotransaccion(dbapi_connection, _registro):
        dbapi_connection.isolation_level = None

    @event.listens_for(engine, "begin")
    def _begin_explicito(conexion):
        conexion.exec_driver_sql("BEGIN")


class Cu11Env:
    """Motor, fábrica de sesiones y override de ``get_db`` para una clase de pruebas."""

    def __init__(self):
        self.engine = build_engine()
        self.SessionLocal = sessionmaker(
            bind=self.engine, autocommit=False, autoflush=False, expire_on_commit=False
        )

    def install(self):
        def override_get_db():
            db = self.SessionLocal()
            try:
                yield db
            finally:
                db.close()

        app.dependency_overrides[get_db] = override_get_db

    def uninstall(self):
        app.dependency_overrides.pop(get_db, None)
        self.engine.dispose()

    def reset(self):
        """Vacía todas las tablas (orden inverso de dependencias)."""
        with self.engine.begin() as conn:
            for table in reversed(Base.metadata.sorted_tables):
                conn.execute(table.delete())


def seed_clinicas_roles_permisos(db, con_matriz_cu11=True):
    """Dos clínicas con roles ADMIN/MEDICO/RECEPCION/PACIENTE y permisos de CU12 (y de CU11 si se pide).

    Devuelve ``{'roles': {(id_clinica, nombre): id_rol}, 'permisos': {nombre: id_permiso}}``.
    """
    db.add_all([
        Clinica(id_clinica=1, nombre="Clínica San Juan", estado="ACTIVO"),
        Clinica(id_clinica=2, nombre="Clínica del Norte", estado="ACTIVO"),
    ])
    db.flush()
    roles = {}
    for id_clinica in (1, 2):
        for nombre in MATRIZ_DOCUMENTS:
            rol = Rol(id_clinica=id_clinica, nombre=nombre, descripcion=nombre, estado="ACTIVO")
            db.add(rol)
            db.flush()
            roles[(id_clinica, nombre)] = rol.id_rol
    permisos = {}
    nombres = PERMISOS_DOCUMENTS + (PERMISOS_LAB_RESULTS if con_matriz_cu11 else ())
    for nombre in nombres:
        permiso = Permiso(nombre=nombre, descripcion=nombre, modulo="seed", accion=nombre, estado="ACTIVO")
        db.add(permiso)
        db.flush()
        permisos[nombre] = permiso.id_permiso
    for (id_clinica, nombre), id_rol in roles.items():
        asignar = MATRIZ_DOCUMENTS[nombre] + (MATRIZ_LAB_RESULTS[nombre] if con_matriz_cu11 else ())
        for permiso in asignar:
            db.add(RolPermiso(id_rol=id_rol, id_permiso=permisos[permiso]))
    db.commit()
    return {"roles": roles, "permisos": permisos}


def seed_dominio_basico(db, ids):
    """Usuarios, pacientes (uno sin clínica), catálogo, orden firmada y fuente de la clínica 1."""
    roles = ids["roles"]
    admin = Usuario(
        id_clinica=1, id_rol=roles[(1, "ADMIN")], nombres="Admin", apellidos="Uno",
        correo="admin1@cu11.test", password_hash="x", estado="ACTIVO",
    )
    medico = Usuario(
        id_clinica=1, id_rol=roles[(1, "MEDICO")], nombres="Medico", apellidos="Uno",
        correo="medico1@cu11.test", password_hash="x", estado="ACTIVO",
    )
    db.add_all([admin, medico])
    db.flush()
    pac1 = Paciente(
        id_clinica=1, nombres="Carlos", apellidos="Mamani", ci="1111111", complemento="",
        fecha_nacimiento=date(1990, 1, 1), genero="M", telefono="70000001",
    )
    pac2 = Paciente(
        id_clinica=2, nombres="Luis", apellidos="Norte", ci="2222222", complemento="",
        fecha_nacimiento=date(1985, 5, 5), genero="M", telefono="70000002",
    )
    pac_sin_clinica = Paciente(
        id_clinica=None, nombres="Maria", apellidos="Sin Clinica", ci="3333333", complemento=None,
        fecha_nacimiento=date(1980, 3, 3), genero="F", telefono="70000003",
    )
    db.add_all([pac1, pac2, pac_sin_clinica])
    examen = ExamenLaboratorio(id_clinica=1, codigo="HEMOGRAMA", nombre="Hemograma completo", categoria="HEMATOLOGIA")
    db.add(examen)
    db.flush()
    orden = OrdenLaboratorio(
        id_clinica=1, id_paciente=pac1.id_paciente, id_medico=medico.id_usuario,
        examenes=[{"codigo": "HEMOGRAMA", "nombre": "Hemograma completo", "indicaciones": None}],
        fecha_orden=date(2026, 11, 1), estado="FIRMADA",
    )
    fuente = FuenteLaboratorio(id_clinica=1, codigo="LAB-CENTRAL", nombre="Laboratorio Central")
    db.add_all([orden, fuente])
    db.commit()
    return {
        "admin": admin, "medico": medico, "pac1": pac1, "pac2": pac2, "pac_sin_clinica": pac_sin_clinica,
        "examen": examen, "orden": orden, "fuente": fuente,
    }


def resultado_valido(**cambios):
    """Datos mínimos de un resultado MANUAL INCORPORADO válido (id_clinica/paciente/examen a completar)."""
    datos = dict(
        codigo_examen="HEMOGRAMA", laboratorio_origen="Lab Central", fecha_realizacion=date(2026, 11, 10),
        estado="INCORPORADO", origen="MANUAL", nombre_archivo="r.pdf", archivo_url="documentos/aa/bb/r.pdf",
        hash_archivo="a" * 64, content_type="application/pdf", tamano_bytes=1000, registrado_por=1,
    )
    datos.update(cambios)
    return datos


# --------------------------------------------------------------------------- #
# Migración 025 sobre SQLite desechable (sin base compartida)
# --------------------------------------------------------------------------- #
import importlib.util
from pathlib import Path

from alembic.migration import MigrationContext
from alembic.operations import Operations

RAIZ = Path(__file__).resolve().parents[1]
RUTA_MIGRACION_025 = RAIZ / "alembic" / "versions" / "025_resultados_laboratorio_cu11.py"
TABLAS_CU11 = (
    "fuentes_laboratorio",
    "sincronizaciones_laboratorio",
    "resultados_laboratorio",
    "sincronizaciones_laboratorio_items",
)


def cargar_migracion_025():
    """Importa el archivo de la revisión 025 (su nombre empieza por dígitos)."""
    spec = importlib.util.spec_from_file_location("cu11_migracion_025", RUTA_MIGRACION_025)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


def engine_previo_a_cu11():
    """SQLite con todas las tablas existentes antes de la revisión 025 (sin las de CU11)."""
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    previas = [t for t in Base.metadata.sorted_tables if t.name not in TABLAS_CU11]
    Base.metadata.create_all(engine, tables=previas)
    return engine


def correr_en_migracion(engine, funcion):
    """Ejecuta ``funcion()`` con el contexto de operaciones de Alembic enlazado a ``engine``."""
    with engine.begin() as conexion:
        contexto = MigrationContext.configure(conexion)
        with Operations.context(contexto):
            return funcion()


# --------------------------------------------------------------------------- #
# Entorno HTTP del grupo 3: personas, almacenamiento temporal y archivos de prueba
# --------------------------------------------------------------------------- #
from datetime import datetime, timezone  # noqa: E402

from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import func, select  # noqa: E402

from app.modules.auth.dependencies import get_current_user  # noqa: E402
from app.modules.medical_records.clinical_documents.models import DocumentoClinico  # noqa: E402
from app.modules.medical_records.clinical_documents.storage import storage as storage_singleton  # noqa: E402

URL = "/api/v1/resultados-laboratorio"


class Cu11Http(Cu11Env):
    """``Cu11Env`` + cliente HTTP. La autenticación se simula sobrescribiendo ``get_current_user``."""

    def __init__(self):
        super().__init__()
        self.client = TestClient(app, raise_server_exceptions=False)

    def cargar_usuario(self, id_usuario):
        """Usuario recién leído de la base (con ``rol_rel`` cargado), como en una petición real."""
        with self.SessionLocal() as sesion:
            return sesion.get(Usuario, id_usuario)

    def como(self, usuario):
        id_usuario = usuario.id_usuario
        app.dependency_overrides[get_current_user] = lambda: self.cargar_usuario(id_usuario)

    def anonimo(self):
        app.dependency_overrides.pop(get_current_user, None)

    def uninstall(self):
        app.dependency_overrides.pop(get_current_user, None)
        super().uninstall()

    def contar(self, modelo, *condiciones):
        with self.SessionLocal() as sesion:
            return sesion.execute(select(func.count()).select_from(modelo).where(*condiciones)).scalar_one()

    def uno(self, modelo, *condiciones):
        with self.SessionLocal() as sesion:
            return sesion.execute(select(modelo).where(*condiciones)).scalars().first()


def pdf_bytes(extra=b""):
    return b"%PDF-1.4\n%resultado de prueba\n" + extra + b"\n%%EOF\n"


def png_bytes(extra=b""):
    return b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\rIHDR" + extra


def jpg_bytes(extra=b""):
    return b"\xff\xd8\xff\xe0\x00\x10JFIF\x00" + extra + b"\xff\xd9"


def cantidad_de_archivos(directorio):
    return sum(1 for ruta in Path(directorio).rglob("*") if ruta.is_file())


def seed_personas(db, ids, datos):
    """Usuarios de prueba por rol y clínica, pacientes con cuenta y una cuenta global sin clínica."""
    roles = ids["roles"]
    rol_sin_permisos = Rol(id_clinica=1, nombre="SIN_PERMISOS", descripcion="sin permisos", estado="ACTIVO")
    db.add(rol_sin_permisos)
    db.flush()

    def usuario(id_clinica, id_rol, correo, nombres="Persona"):
        u = Usuario(
            id_clinica=id_clinica, id_rol=id_rol, nombres=nombres, apellidos="Prueba",
            correo=correo, password_hash="x", estado="ACTIVO",
        )
        db.add(u)
        db.flush()
        return u

    personas = {
        "admin1": datos["admin"],
        "medico1": datos["medico"],
        "recepcion1": usuario(1, roles[(1, "RECEPCION")], "recepcion1@cu11.test", "Recepcion"),
        "paciente1": usuario(1, roles[(1, "PACIENTE")], "paciente1@cu11.test", "Carlos"),
        "paciente1b": usuario(1, roles[(1, "PACIENTE")], "paciente1b@cu11.test", "Ana"),
        "paciente_sin_clinica": usuario(1, roles[(1, "PACIENTE")], "pac_sinclinica@cu11.test", "Rosa"),
        "sin_permisos1": usuario(1, rol_sin_permisos.id_rol, "sinpermisos1@cu11.test"),
        "admin2": usuario(2, roles[(2, "ADMIN")], "admin2@cu11.test", "AdminNorte"),
        "medico2": usuario(2, roles[(2, "MEDICO")], "medico2@cu11.test", "MedicoNorte"),
        "global": usuario(None, roles[(1, "ADMIN")], "global@cu11.test", "Global"),
    }
    propio = Paciente(
        id_clinica=1, id_usuario=personas["paciente1"].id_usuario, nombres="Carlos", apellidos="Propio",
        ci="5555551", complemento="", fecha_nacimiento=date(1991, 2, 2), genero="M", telefono="70000011",
    )
    ajeno = Paciente(
        id_clinica=1, id_usuario=personas["paciente1b"].id_usuario, nombres="Ana", apellidos="Ajena",
        ci="5555552", complemento="", fecha_nacimiento=date(1992, 3, 3), genero="F", telefono="70000012",
    )
    # cuenta de paciente cuyo perfil NO tiene clínica (como los pacientes 1 y 2 de Neon)
    huerfano = Paciente(
        id_clinica=None, id_usuario=personas["paciente_sin_clinica"].id_usuario, nombres="Rosa",
        apellidos="Huerfana", ci="5555553", complemento="", fecha_nacimiento=date(1993, 4, 4),
        genero="F", telefono="70000013",
    )
    db.add_all([propio, ajeno, huerfano])
    db.commit()
    personas.update({"pac_propio": propio, "pac_ajeno": ajeno, "pac_huerfano": huerfano})
    return personas


def crear_resultado_db(db, id_clinica, id_paciente, id_examen, registrado_por, **cambios):
    """Inserta un resultado directamente en la base (sin pasar por el servicio)."""
    datos = resultado_valido(
        id_clinica=id_clinica, id_paciente=id_paciente, id_examen=id_examen, registrado_por=registrado_por
    )
    datos.update(cambios)
    resultado = ResultadoLaboratorio(**datos)
    db.add(resultado)
    db.commit()
    return resultado


def crear_pendiente_db(db, id_clinica, registrado_por, id_fuente, **cambios):
    """Resultado sincronizado en PENDIENTE_REVISION (sin paciente ni documento)."""
    datos = resultado_valido(
        id_clinica=id_clinica, id_paciente=None, id_examen=None, registrado_por=registrado_por,
        estado="PENDIENTE_REVISION", origen="SINCRONIZADO", id_fuente=id_fuente,
        id_externo=cambios.pop("id_externo", "EXT-PEND-1"), motivo_pendiente="PACIENTE_NO_ENCONTRADO",
        datos_correspondencia={"ci": "9999999", "complemento": "", "codigo_examen": "HEMOGRAMA"},
        hash_archivo=cambios.pop("hash_archivo", "9" * 64),
    )
    datos.update(cambios)
    resultado = ResultadoLaboratorio(**datos)
    db.add(resultado)
    db.commit()
    return resultado


from types import SimpleNamespace  # noqa: E402


def usar_storage_temporal(monkeypatch, directorio):
    """Aísla el singleton de almacenamiento en un directorio temporal: ningún archivo sale de ``tmp_path``."""
    almacen = Path(directorio) / "storage"
    almacen.mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr(storage_singleton, "backend", "local")
    monkeypatch.setattr(storage_singleton, "_s3_client", None)
    monkeypatch.setattr(storage_singleton, "local_dir", almacen)
    return almacen


def construir_mundo(env, almacen):
    """Dos clínicas con roles y permisos, dominio básico y personas; devuelve un espacio de nombres."""
    env.reset()
    env.anonimo()
    with env.SessionLocal() as db:
        ids = seed_clinicas_roles_permisos(db)
        datos = seed_dominio_basico(db, ids)
        personas = seed_personas(db, ids, datos)
        # catálogo y orden de la clínica 2 (para pruebas de aislamiento)
        examen2 = ExamenLaboratorio(id_clinica=2, codigo="GLUCOSA", nombre="Glucosa", categoria="BIOQUIMICA")
        db.add(examen2)
        db.commit()
    return SimpleNamespace(
        env=env, client=env.client, ids=ids, datos=datos, p=personas, almacen=almacen, examen2=examen2,
    )


def post_manual(mundo, usuario=None, *, archivo=None, campos=None, quitar=(), headers=None):
    """POST multipart de carga manual con valores por defecto válidos (pac1, HEMOGRAMA)."""
    if usuario is not None:
        mundo.env.como(usuario)
    datos = {
        "id_paciente": str(mundo.datos["pac1"].id_paciente),
        "codigo_examen": "HEMOGRAMA",
        "fecha_realizacion": "2026-11-10",
        "laboratorio_origen": "Laboratorio Central",
    }
    datos.update(campos or {})
    for clave in quitar:
        datos.pop(clave, None)
    archivos = {}
    if "archivo" not in quitar:
        archivos["archivo"] = archivo or ("hemograma.pdf", pdf_bytes(), "application/pdf")
    return mundo.client.post(URL, data=datos, files=archivos or None, headers=headers or {})
