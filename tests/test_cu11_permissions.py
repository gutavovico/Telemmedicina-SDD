"""CU11 · tareas 2.3 y 2.6: matriz de permisos sembrada por la migración 025 y asignación manual.

El sembrado se ejecuta con la propia migración sobre SQLite desechable. La tarea 2.6 confirma que no hay
nada que tocar en el alta de clínicas: los permisos nuevos se asignan a mano desde ``auth/roles_permissions``.
"""
import pytest
from sqlalchemy import select, text

from app.modules.auth.models import Permiso, Rol, RolPermiso
from app.modules.auth.roles_permissions import service as roles_service
from app.modules.medical_records.clinical_documents.dependencies import user_has_permission
from cu11_support import (
    MATRIZ_DOCUMENTS,
    MATRIZ_LAB_RESULTS,
    PERMISOS_LAB_RESULTS,
    Cu11Env,
    cargar_migracion_025,
    correr_en_migracion,
    engine_previo_a_cu11,
    seed_clinicas_roles_permisos,
)


def _roles_y_permisos(conexion):
    filas = conexion.execute(text(
        "SELECT r.id_clinica, r.nombre, p.nombre FROM rol_permisos rp "
        "JOIN roles r ON r.id_rol = rp.id_rol JOIN permisos p ON p.id_permiso = rp.id_permiso "
        "WHERE p.nombre LIKE 'lab_results:%'"
    )).all()
    resultado = {}
    for id_clinica, rol, permiso in filas:
        resultado.setdefault((id_clinica, rol), set()).add(permiso)
    return resultado


@pytest.fixture()
def base_con_roles():
    """SQLite previa a la 025 con roles de dos clínicas (más variantes que NO deben recibir permisos)."""
    engine = engine_previo_a_cu11()
    from sqlalchemy.orm import sessionmaker
    Sesion = sessionmaker(bind=engine, expire_on_commit=False)
    with Sesion() as db:
        from app.modules.auth.models import Clinica
        db.add_all([Clinica(id_clinica=1, nombre="C1", estado="ACTIVO"), Clinica(id_clinica=2, nombre="C2", estado="ACTIVO")])
        db.flush()
        for id_clinica in (1, 2):
            for nombre in ("ADMIN", "MEDICO", "RECEPCION", "PACIENTE"):
                db.add(Rol(id_clinica=id_clinica, nombre=nombre, estado="ACTIVO"))
        # variantes de nombre: se comparan en mayúsculas (como CU12) y "Administrador" no coincide con ADMIN
        db.add(Rol(id_clinica=2, nombre="medico", estado="ACTIVO"))
        db.add(Rol(id_clinica=2, nombre="Administrador", estado="ACTIVO"))
        db.commit()
    return engine


def test_matriz_exacta_de_permisos_sembrada_por_la_migracion(base_con_roles):
    migracion = cargar_migracion_025()
    correr_en_migracion(base_con_roles, migracion.upgrade)
    with base_con_roles.connect() as conexion:
        asignado = _roles_y_permisos(conexion)
        esperado = {}
        for id_clinica in (1, 2):
            for rol, permisos in MATRIZ_LAB_RESULTS.items():
                esperado[(id_clinica, rol)] = set(permisos)
        esperado[(2, "medico")] = set(MATRIZ_LAB_RESULTS["MEDICO"])
        assert asignado == esperado
        # "Administrador" (rol que crea auth/clinicas) no coincide con ADMIN y no recibe nada por migración
        assert (2, "Administrador") not in asignado
        # los cuatro permisos existen, activos y del módulo laboratory_results
        filas = conexion.execute(text(
            "SELECT nombre, modulo, estado FROM permisos WHERE nombre LIKE 'lab_results:%' ORDER BY nombre"
        )).all()
        assert [f[0] for f in filas] == sorted(PERMISOS_LAB_RESULTS)
        assert {f[1] for f in filas} == {"laboratory_results"} and {f[2] for f in filas} == {"ACTIVO"}


def test_no_se_crea_ningun_rol_laboratorio(base_con_roles):
    with base_con_roles.connect() as conexion:
        antes = conexion.execute(text("SELECT count(*) FROM roles")).scalar_one()
    correr_en_migracion(base_con_roles, cargar_migracion_025().upgrade)
    with base_con_roles.connect() as conexion:
        assert conexion.execute(text("SELECT count(*) FROM roles")).scalar_one() == antes
        assert conexion.execute(text("SELECT count(*) FROM roles WHERE UPPER(nombre) = 'LABORATORIO'")).scalar_one() == 0


def test_sembrado_idempotente_no_duplica_filas(base_con_roles):
    migracion = cargar_migracion_025()
    correr_en_migracion(base_con_roles, migracion.upgrade)
    with base_con_roles.connect() as conexion:
        permisos = conexion.execute(text("SELECT count(*) FROM permisos")).scalar_one()
        asignaciones = conexion.execute(text("SELECT count(*) FROM rol_permisos")).scalar_one()
    correr_en_migracion(base_con_roles, migracion.sembrar_permisos)
    correr_en_migracion(base_con_roles, migracion.sembrar_permisos)
    with base_con_roles.connect() as conexion:
        assert conexion.execute(text("SELECT count(*) FROM permisos")).scalar_one() == permisos
        assert conexion.execute(text("SELECT count(*) FROM rol_permisos")).scalar_one() == asignaciones


def test_downgrade_retira_solo_los_permisos_de_cu11(base_con_roles):
    from sqlalchemy.orm import sessionmaker
    migracion = cargar_migracion_025()
    with sessionmaker(bind=base_con_roles)() as db:
        permiso = Permiso(nombre="documents:download", modulo="medical_records", accion="download", estado="ACTIVO")
        db.add(permiso)
        db.flush()
        rol = db.scalars(select(Rol).where(Rol.nombre == "ADMIN", Rol.id_clinica == 1)).one()
        db.add(RolPermiso(id_rol=rol.id_rol, id_permiso=permiso.id_permiso))
        db.commit()
    correr_en_migracion(base_con_roles, migracion.upgrade)
    correr_en_migracion(base_con_roles, migracion.downgrade)
    with base_con_roles.connect() as conexion:
        assert conexion.execute(text("SELECT count(*) FROM permisos WHERE nombre LIKE 'lab_results:%'")).scalar_one() == 0
        assert conexion.execute(text("SELECT count(*) FROM permisos WHERE nombre = 'documents:download'")).scalar_one() == 1
        assert conexion.execute(text("SELECT count(*) FROM rol_permisos")).scalar_one() == 1


# ----------------------------------- tarea 2.6 ---------------------------------------- #
@pytest.fixture()
def entorno_sembrado():
    entorno = Cu11Env()
    with entorno.SessionLocal() as db:
        ids = seed_clinicas_roles_permisos(db, con_matriz_cu11=False)
    # permisos y asignaciones de CU11 por la propia migración sobre las tablas ya creadas
    correr_en_migracion(entorno.engine, cargar_migracion_025().sembrar_permisos)
    yield entorno, ids
    entorno.engine.dispose()


def test_asignacion_manual_en_rol_nuevo(entorno_sembrado):
    """Un rol creado como en `auth/clinicas` no recibe `lab_results:*`; se asigna con `auth/roles_permissions`."""
    entorno, ids = entorno_sembrado
    with entorno.SessionLocal() as db:
        # 1) los permisos nuevos aparecen solos en el listado de permisos del módulo de roles
        nombres = {p["nombre"] for p in roles_service.list_permissions(db)}
        assert set(PERMISOS_LAB_RESULTS) <= nombres

        # 2) rol creado exactamente como lo hace auth/clinicas/service.py al registrar una clínica
        from app.modules.auth.models import Clinica
        db.add(Clinica(id_clinica=3, nombre="Clínica nueva", estado="ACTIVO"))
        db.flush()
        admin_nuevo = Rol(id_clinica=3, nombre="Administrador", descripcion="Administrador principal de la clínica", estado="ACTIVO")
        db.add(admin_nuevo)
        db.commit()
        for permiso in PERMISOS_LAB_RESULTS:
            assert user_has_permission(db, admin_nuevo.id_rol, permiso) is False

        # 3) asignación manual desde el módulo de roles y permisos
        id_permisos = [p["id_permiso"] for p in roles_service.list_permissions(db) if p["nombre"] in PERMISOS_LAB_RESULTS]
        roles_service.replace_role_permissions(db, admin_nuevo.id_rol, id_permisos, current_tenant_id=3)
        for permiso in PERMISOS_LAB_RESULTS:
            assert user_has_permission(db, admin_nuevo.id_rol, permiso) is True


def test_la_matriz_de_cu11_es_coherente_con_la_de_cu12(entorno_sembrado):
    """RECEPCION puede cargar y leer metadatos, pero sin `documents:read:lab_results` no descarga archivos."""
    entorno, ids = entorno_sembrado
    with entorno.SessionLocal() as db:
        def tiene(rol, permiso, clinica=1):
            return user_has_permission(db, ids["roles"][(clinica, rol)], permiso)

        for rol, permisos in MATRIZ_LAB_RESULTS.items():
            for permiso in PERMISOS_LAB_RESULTS:
                assert tiene(rol, permiso) == (permiso in permisos), (rol, permiso)
        assert tiene("RECEPCION", "lab_results:read") and not tiene("RECEPCION", "documents:read:lab_results")
        assert tiene("RECEPCION", "documents:download")  # por eso la descarga de CU11 no se apoya en este permiso
        assert not tiene("PACIENTE", "lab_results:create") and tiene("PACIENTE", "documents:read:lab_results")
        assert tiene("MEDICO", "lab_results:review") and not tiene("MEDICO", "lab_results:sync")
        assert all(tiene("ADMIN", p) for p in PERMISOS_LAB_RESULTS)
        # la matriz de CU12 sembrada en la semilla coincide con las migraciones 004 y 006
        assert "documents:read:lab_results" not in MATRIZ_DOCUMENTS["RECEPCION"]


# ===================== tarea 3.3: clínica estricta y permisos en los endpoints ===================== #
import inspect as _inspect  # noqa: E402
from pathlib import Path as _Path  # noqa: E402

from app.modules.auth.models import Rol as _Rol  # noqa: E402
from cu11_support import (  # noqa: E402
    URL,
    Cu11Http,
    construir_mundo,
    pdf_bytes,
    post_manual,
    usar_storage_temporal,
)


@pytest.fixture(scope="module")
def env_http():
    entorno = Cu11Http()
    entorno.install()
    yield entorno
    entorno.uninstall()


@pytest.fixture()
def mundo(env_http, tmp_path, monkeypatch):
    return construir_mundo(env_http, usar_storage_temporal(monkeypatch, tmp_path))


ENDPOINTS = [
    ("post", URL, "crear"),
    ("get", URL, None),
    ("get", f"{URL}/me", None),
    ("get", "/api/v1/pacientes/1/resultados-laboratorio", None),
    ("get", f"{URL}/1", None),
    ("get", f"{URL}/1/archivo", None),
    ("post", f"{URL}/1/resolver", {"accion": "DESCARTAR", "motivo": "No corresponde"}),
    ("post", f"{URL}/1/anular", {"motivo": "No corresponde"}),
]


def _llamar(mundo, metodo, ruta, cuerpo):
    if cuerpo == "crear":
        return post_manual(mundo)
    if metodo == "post":
        return mundo.client.post(ruta, json=cuerpo)
    return mundo.client.get(ruta)


@pytest.mark.parametrize("metodo,ruta,cuerpo", ENDPOINTS)
def test_sin_token_da_401_en_todos_los_endpoints(mundo, metodo, ruta, cuerpo):
    mundo.env.anonimo()
    assert _llamar(mundo, metodo, ruta, cuerpo).status_code == 401


@pytest.mark.parametrize("metodo,ruta,cuerpo", ENDPOINTS)
def test_cuenta_sin_clinica_da_403_en_todos_los_endpoints(mundo, metodo, ruta, cuerpo):
    mundo.env.como(mundo.p["global"])
    respuesta = _llamar(mundo, metodo, ruta, cuerpo)
    assert respuesta.status_code == 403 and "clínica" in respuesta.text


@pytest.mark.parametrize("metodo,ruta,cuerpo", ENDPOINTS)
def test_usuario_sin_ningun_permiso_da_403_en_todos_los_endpoints(mundo, metodo, ruta, cuerpo):
    mundo.env.como(mundo.p["sin_permisos1"])
    respuesta = _llamar(mundo, metodo, ruta, cuerpo)
    assert respuesta.status_code == 403 and "Permiso denegado" in respuesta.text


def test_cada_endpoint_exige_el_permiso_que_le_corresponde(mundo):
    # PACIENTE solo tiene lab_results:read
    mundo.env.como(mundo.p["paciente1"])
    assert post_manual(mundo).status_code == 403
    for ruta, cuerpo in ((f"{URL}/1/resolver", {"accion": "DESCARTAR", "motivo": "abc"}), (f"{URL}/1/anular", {"motivo": "abc"})):
        assert mundo.client.post(ruta, json=cuerpo).status_code == 403
    # RECEPCION: create + read, pero no review
    mundo.env.como(mundo.p["recepcion1"])
    assert mundo.client.post(f"{URL}/1/anular", json={"motivo": "abc"}).status_code == 403
    assert mundo.client.get(f"{URL}?estado=ANULADO").status_code == 403


def test_la_descarga_exige_los_dos_permisos(mundo):
    """`documents:read:lab_results` solo, sin `lab_results:read`, tampoco alcanza (y viceversa: recepcion)."""
    with mundo.env.SessionLocal() as db:
        rol = _Rol(id_clinica=1, nombre="SOLO_DESCARGA", estado="ACTIVO")
        db.add(rol)
        db.flush()
        from app.modules.auth.models import Permiso, RolPermiso, Usuario
        id_permiso = db.execute(select(Permiso.id_permiso).where(Permiso.nombre == "documents:read:lab_results")).scalar_one()
        db.add(RolPermiso(id_rol=rol.id_rol, id_permiso=id_permiso))
        usuario = Usuario(id_clinica=1, id_rol=rol.id_rol, nombres="Solo", apellidos="Descarga",
                          correo="solodescarga@cu11.test", password_hash="x", estado="ACTIVO")
        db.add(usuario)
        db.commit()
        id_usuario = usuario.id_usuario
    creado = post_manual(mundo, mundo.p["medico1"]).json()
    mundo.env.como(mundo.env.cargar_usuario(id_usuario))
    respuesta = mundo.client.get(f"{URL}/{creado['id_resultado']}/archivo")
    assert respuesta.status_code == 403 and "lab_results:read" in respuesta.text
    mundo.env.como(mundo.p["recepcion1"])
    respuesta = mundo.client.get(f"{URL}/{creado['id_resultado']}/archivo")
    assert respuesta.status_code == 403 and "documents:read:lab_results" in respuesta.text


def test_la_clinica_siempre_sale_de_la_sesion_y_nunca_del_encabezado(mundo):
    creado = post_manual(mundo, mundo.p["medico1"], headers={"X-Tenant-ID": "2"})
    assert creado.status_code == 201 and creado.json()["id_clinica"] == 1
    mundo.env.como(mundo.p["admin2"])
    lista = mundo.client.get(URL, headers={"X-Tenant-ID": "1"})  # intenta mirar la clínica 1 con un encabezado
    assert lista.status_code == 200 and lista.json()["total"] == 0
    mundo.env.como(mundo.p["global"])
    assert mundo.client.get(URL, headers={"X-Tenant-ID": "1"}).status_code == 403  # la cuenta global no elige clínica


def test_los_modulos_de_cu11_no_usan_los_helpers_de_tenant_prohibidos():
    """Análisis sintáctico: un docstring que mencione el helper no cuenta, pero importarlo o llamarlo sí."""
    import ast
    prohibidos = {"get_required_tenant_id", "get_current_tenant_id"}
    raiz = _Path(__file__).resolve().parents[1] / "app" / "modules" / "medical_records" / "laboratory_results"
    for archivo in raiz.glob("*.py"):
        arbol = ast.parse(archivo.read_text(encoding="utf-8"))
        usados = set()
        for nodo in ast.walk(arbol):
            if isinstance(nodo, ast.Name):
                usados.add(nodo.id)
            elif isinstance(nodo, ast.Attribute):
                usados.add(nodo.attr)
            elif isinstance(nodo, (ast.Import, ast.ImportFrom)):
                usados.update(alias.name.split(".")[-1] for alias in nodo.names)
        assert not (usados & prohibidos), (archivo.name, usados & prohibidos)


# ===================== tarea 3.10: rutas del contrato registradas sin tocar main.py ===================== #
def test_openapi_lista_exactamente_las_rutas_del_contrato(mundo):
    paths = mundo.client.get("/openapi.json").json()["paths"]
    esperadas = {
        ("post", "/api/v1/resultados-laboratorio"),
        ("get", "/api/v1/resultados-laboratorio"),
        ("get", "/api/v1/resultados-laboratorio/me"),
        ("get", "/api/v1/pacientes/{id_paciente}/resultados-laboratorio"),
        ("get", "/api/v1/resultados-laboratorio/{id_resultado}"),
        ("get", "/api/v1/resultados-laboratorio/{id_resultado}/archivo"),
        ("post", "/api/v1/resultados-laboratorio/{id_resultado}/resolver"),
        ("post", "/api/v1/resultados-laboratorio/{id_resultado}/anular"),
    }
    publicadas = {
        (metodo, ruta) for ruta, ops in paths.items() if "resultados-laboratorio" in ruta for metodo in ops
    }
    assert publicadas == esperadas
    # el multipart de carga no publica id_clinica/tenant_id como campos aceptados
    esquema = paths["/api/v1/resultados-laboratorio"]["post"]["requestBody"]["content"]["multipart/form-data"]["schema"]
    componente = mundo.client.get("/openapi.json").json()["components"]["schemas"][esquema["$ref"].split("/")[-1]]
    assert not {"id_clinica", "tenant_id", "estado", "origen"} & set(componente["properties"])


def test_main_py_no_registra_los_routers_de_cu11():
    main = (_Path(__file__).resolve().parents[1] / "app" / "main.py").read_text(encoding="utf-8")
    assert "laboratory_results" not in main and "resultados-laboratorio" not in main
