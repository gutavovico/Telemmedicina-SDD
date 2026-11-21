"""CU11 · bloque B sobre PostgreSQL real: unicidad, SAVEPOINT por ítem y carrera concurrente.

Se omite salvo que ``CU11_TEST_PG_URL`` apunte a un PostgreSQL DESECHABLE ya migrado con
``alembic upgrade head`` (por ejemplo un contenedor local ``pgvector/pgvector:pg16``). Nunca apuntar a una base
compartida: las pruebas crean y NO borran sus propios datos (clínica con nombre único).

    CU11_TEST_PG_URL=postgresql+psycopg2://postgres:<pw>@127.0.0.1:55433/<db> python -m pytest tests/test_cu11_sync_postgres.py

Complementa a las pruebas con SQLite: allí la carrera se simula insertando la fila entre la verificación y el
INSERT; aquí además se ejecuta una carrera REAL con dos hilos y dos conexiones, y se comprueba que el SAVEPOINT
y la restricción única se comportan igual que en la base de producción.
"""
import hashlib
import io
import json
import os
import threading
import uuid
from datetime import date

import pytest
from sqlalchemy import create_engine, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

PG_URL = os.environ.get("CU11_TEST_PG_URL")
pytestmark = pytest.mark.skipif(not PG_URL, reason="CU11_TEST_PG_URL no definido (PostgreSQL desechable)")

if PG_URL:  # las importaciones de la aplicación solo cuando se va a usar la base
    from app.modules.auth.models import Clinica, Usuario
    from app.modules.medical_records.clinical_documents.models import DocumentoClinico
    from app.modules.medical_records.clinical_documents.storage import storage as storage_singleton
    from app.modules.medical_records.laboratory_orders.models import ExamenLaboratorio
    from app.modules.medical_records.laboratory_results.dependencies import Contexto
    from app.modules.medical_records.laboratory_results.models import ResultadoLaboratorio
    from app.modules.medical_records.laboratory_sync import service as sync_service
    from app.modules.medical_records.laboratory_sync.models import (
        FuenteLaboratorio,
        SincronizacionLaboratorio,
        SincronizacionLaboratorioItem,
    )
    from app.modules.medical_records.models import Paciente
    from cu11_support import cantidad_de_archivos, pdf_bytes


class Parte:
    """Parte ``archivos`` mínima (lo que usa el servicio de ``UploadFile``)."""

    def __init__(self, filename, datos, content_type="application/pdf"):
        self.filename, self.content_type, self.file = filename, content_type, io.BytesIO(datos)


@pytest.fixture(scope="module")
def engine():
    motor = create_engine(PG_URL, pool_pre_ping=True)
    yield motor
    motor.dispose()


@pytest.fixture()
def Sesion(engine):
    return sessionmaker(bind=engine, autocommit=False, autoflush=False, expire_on_commit=False)


@pytest.fixture()
def almacen(tmp_path, monkeypatch):
    destino = tmp_path / "storage"
    destino.mkdir()
    monkeypatch.setattr(storage_singleton, "backend", "local")
    monkeypatch.setattr(storage_singleton, "_s3_client", None)
    monkeypatch.setattr(storage_singleton, "local_dir", destino)
    return destino


@pytest.fixture()
def clinica(Sesion):
    """Clínica propia de la prueba (nombre único): usuario, paciente, estudio y fuente."""
    sufijo = uuid.uuid4().hex[:10]
    with Sesion() as db:
        c = Clinica(nombre=f"Clinica PG {sufijo}", estado="ACTIVO")
        db.add(c)
        db.flush()
        u = Usuario(
            id_clinica=c.id_clinica, nombres="Admin", apellidos="PG", correo=f"admin-{sufijo}@cu11pg.test",
            password_hash="x", estado="ACTIVO",
        )
        db.add(u)
        db.flush()
        p = Paciente(
            id_clinica=c.id_clinica, nombres="Paciente", apellidos="Pg", ci=f"9{int(sufijo, 16) % 10**8:08d}",
            complemento="", fecha_nacimiento=date(1990, 1, 1), genero="M", telefono="70000000",
        )
        e = ExamenLaboratorio(id_clinica=c.id_clinica, codigo="HEMOGRAMA", nombre="Hemograma completo", categoria="HEMATOLOGIA")
        f = FuenteLaboratorio(id_clinica=c.id_clinica, codigo="LAB-PG", nombre="Fuente PG")
        db.add_all([p, e, f])
        db.commit()
        return type("Clinica", (), {
            "id": c.id_clinica, "usuario": u.id_usuario, "ci": p.ci, "id_paciente": p.id_paciente,
            "id_fuente": f.id_fuente, "id_examen": e.id_examen,
        })


def contexto(clinica):
    return Contexto(id_usuario=clinica.usuario, id_clinica=clinica.id, id_rol=None, rol=None)


def manifiesto(clinica, *externos, ci=None):
    items = [
        {
            "id_externo": e, "ci": ci or clinica.ci, "complemento": "", "codigo_examen": "HEMOGRAMA",
            "laboratorio_origen": "Laboratorio PG", "fecha_realizacion": "2026-11-10", "nombre_archivo": f"{e}.pdf",
        }
        for e in externos
    ]
    return sync_service.parsear_manifiesto(json.dumps({"fuente": "LAB-PG", "items": items}))


def partes(*externos, contenidos=None):
    contenidos = contenidos or {}
    return {f"{e}.pdf": Parte(f"{e}.pdf", contenidos.get(e, pdf_bytes(e.encode()))) for e in externos}


def contar(Sesion, modelo, *condiciones):
    with Sesion() as db:
        return db.execute(select(func.count()).select_from(modelo).where(*condiciones)).scalar_one()


# --------------------------------------------------------------------------- #
# SAVEPOINT y restricción única en PostgreSQL
# --------------------------------------------------------------------------- #
def test_savepoint_deshace_solo_el_item_fallido_y_el_rollback_externo_deshace_todo(Sesion, clinica):
    with Sesion() as db:
        db.add(FuenteLaboratorio(id_clinica=clinica.id, codigo="SP-ANTES", nombre="Antes del savepoint"))
        db.flush()
        with pytest.raises(IntegrityError):
            with db.begin_nested():
                db.add(FuenteLaboratorio(id_clinica=clinica.id, codigo="SP-A", nombre="Primera dentro"))
                db.flush()
                db.add(FuenteLaboratorio(id_clinica=clinica.id, codigo="SP-A", nombre="Repetida dentro"))
                db.flush()
        # la transacción externa sigue viva: lo anterior se conserva y se puede seguir escribiendo
        db.add(FuenteLaboratorio(id_clinica=clinica.id, codigo="SP-DESPUES", nombre="Después del savepoint"))
        db.flush()
        codigos = set(db.execute(select(FuenteLaboratorio.codigo).where(FuenteLaboratorio.id_clinica == clinica.id)).scalars())
        assert codigos == {"LAB-PG", "SP-ANTES", "SP-DESPUES"}      # nada de SP-A: el SAVEPOINT lo deshizo
        db.rollback()
    with Sesion() as db:
        assert set(db.execute(select(FuenteLaboratorio.codigo).where(FuenteLaboratorio.id_clinica == clinica.id)).scalars()) == {"LAB-PG"}


def test_savepoint_posterior_a_un_select_se_anida_de_verdad(Sesion, clinica):
    """Equivalente al caso de pysqlite: SELECT, luego SAVEPOINT; el rollback externo debe deshacer el bloque liberado."""
    with Sesion() as db:
        db.execute(select(FuenteLaboratorio.id_fuente)).all()
        with db.begin_nested():
            db.add(FuenteLaboratorio(id_clinica=clinica.id, codigo="SP-LIBERADO", nombre="Liberado"))
            db.flush()
        db.rollback()
    assert contar(Sesion, FuenteLaboratorio, FuenteLaboratorio.codigo == "SP-LIBERADO") == 0


# --------------------------------------------------------------------------- #
# Lote completo, reenvío y carrera
# --------------------------------------------------------------------------- #
def test_lote_con_cuatro_resultados_distintos_y_reenvio_idempotente(Sesion, clinica, almacen):
    ctx = contexto(clinica)
    items = [
        {"id_externo": "PG-OK", "ci": clinica.ci, "complemento": "", "codigo_examen": "HEMOGRAMA",
         "laboratorio_origen": "Lab", "fecha_realizacion": "2026-11-10", "nombre_archivo": "ok.pdf"},
        {"id_externo": "PG-PEND", "ci": "0000001", "complemento": "", "codigo_examen": "HEMOGRAMA",
         "laboratorio_origen": "Lab", "fecha_realizacion": "2026-11-10", "nombre_archivo": "pend.pdf"},
        {"id_externo": "PG-ERR", "ci": clinica.ci, "complemento": "", "codigo_examen": "HEMOGRAMA",
         "laboratorio_origen": "Lab", "fecha_realizacion": "2026-11-10", "nombre_archivo": "malo.exe"},
        {"id_externo": "PG-ESTUDIO", "ci": clinica.ci, "complemento": "", "codigo_examen": "NO-EXISTE",
         "laboratorio_origen": "Lab", "fecha_realizacion": "2026-11-10", "nombre_archivo": "estudio.pdf"},
    ]
    man = sync_service.parsear_manifiesto(json.dumps({"fuente": "LAB-PG", "items": items}))
    envio = {
        "ok.pdf": Parte("ok.pdf", pdf_bytes(b"ok")), "pend.pdf": Parte("pend.pdf", pdf_bytes(b"pend")),
        "malo.exe": Parte("malo.exe", b"MZ\x90\x00", "application/octet-stream"),
        "estudio.pdf": Parte("estudio.pdf", pdf_bytes(b"estudio")),
    }
    with Sesion() as db:
        primero = sync_service.ejecutar_lote(db, ctx, man, envio)
    por = {i["id_externo"]: i for i in primero["items"]}
    assert por["PG-OK"]["resultado"] == "INCORPORADO"
    assert por["PG-PEND"]["detalle"] == "PACIENTE_NO_ENCONTRADO" and por["PG-ESTUDIO"]["detalle"] == "EXAMEN_NO_VALIDO"
    assert por["PG-ERR"]["codigo_error"] == "ARCHIVO_TIPO_NO_PERMITIDO"
    assert (primero["incorporados"], primero["pendientes"], primero["con_error"], primero["estado"]) == (
        1, 2, 1, "COMPLETADA_CON_ERRORES",
    )
    filas = contar(Sesion, ResultadoLaboratorio, ResultadoLaboratorio.id_clinica == clinica.id)
    archivos = cantidad_de_archivos(almacen)
    assert filas == 3 and archivos == 3

    envio2 = {
        "ok.pdf": Parte("ok.pdf", pdf_bytes(b"ok")), "pend.pdf": Parte("pend.pdf", pdf_bytes(b"pend")),
        "malo.exe": Parte("malo.exe", b"MZ\x90\x00", "application/octet-stream"),
        "estudio.pdf": Parte("estudio.pdf", pdf_bytes(b"estudio")),
    }
    with Sesion() as db:
        segundo = sync_service.ejecutar_lote(db, ctx, man, envio2)
    assert {i["id_externo"]: i["resultado"] for i in segundo["items"]} == {
        "PG-OK": "DUPLICADO", "PG-PEND": "DUPLICADO", "PG-ESTUDIO": "DUPLICADO", "PG-ERR": "ERROR",
    }
    assert contar(Sesion, ResultadoLaboratorio, ResultadoLaboratorio.id_clinica == clinica.id) == 3
    assert cantidad_de_archivos(almacen) == 3
    assert contar(Sesion, DocumentoClinico, DocumentoClinico.id_clinica == clinica.id, DocumentoClinico.tipo_documento == "RESULTADO_LAB") == 1


def test_carrera_simulada_entre_la_verificacion_y_el_insert(Sesion, clinica, almacen, monkeypatch):
    contenido = pdf_bytes(b"carrera pg")
    original = sync_service._buscar_existente
    estado = {"hecho": False}

    def con_carrera(db, id_clinica, id_fuente, id_externo):
        encontrado = original(db, id_clinica, id_fuente, id_externo)
        if id_externo == "PG-RACE" and not estado["hecho"]:
            estado["hecho"] = True
            db.execute(ResultadoLaboratorio.__table__.insert().values(
                id_clinica=id_clinica, id_paciente=clinica.id_paciente, id_examen=clinica.id_examen,
                codigo_examen="HEMOGRAMA", laboratorio_origen="Otro proceso", fecha_realizacion=date(2026, 11, 10),
                estado="INCORPORADO", origen="SINCRONIZADO", id_fuente=id_fuente, id_externo=id_externo,
                nombre_archivo="r.pdf", archivo_url="documentos/zz/zz/competidor.pdf",
                hash_archivo=hashlib.sha256(contenido).hexdigest(), content_type="application/pdf",
                tamano_bytes=len(contenido), registrado_por=clinica.usuario,
            ))
        return encontrado

    monkeypatch.setattr(sync_service, "_buscar_existente", con_carrera)
    man = manifiesto(clinica, "PG-RACE")
    with Sesion() as db:
        cuerpo = sync_service.ejecutar_lote(db, contexto(clinica), man, partes("PG-RACE", contenidos={"PG-RACE": contenido}))
    assert cuerpo["items"][0]["resultado"] == "DUPLICADO"
    assert contar(Sesion, ResultadoLaboratorio, ResultadoLaboratorio.id_clinica == clinica.id, ResultadoLaboratorio.id_externo == "PG-RACE") == 1
    assert cantidad_de_archivos(almacen) == 0


def test_carrera_real_con_dos_conexiones_deja_exactamente_un_resultado(Sesion, clinica, almacen, monkeypatch):
    """Dos hilos, dos conexiones: ambos verifican (sin ver nada) y recién entonces ambos insertan la misma clave."""
    contenido = pdf_bytes(b"carrera real")
    barrera = threading.Barrier(2, timeout=30)
    original = sync_service._buscar_existente
    local = threading.local()

    def espera_a_que_ambos_hayan_verificado(db, id_clinica, id_fuente, id_externo):
        encontrado = original(db, id_clinica, id_fuente, id_externo)
        if id_externo == "PG-REAL" and not getattr(local, "ya_espero", False):
            local.ya_espero = True            # solo la primera verificación de cada hilo; la relectura posterior no espera
            barrera.wait()
        return encontrado

    monkeypatch.setattr(sync_service, "_buscar_existente", espera_a_que_ambos_hayan_verificado)
    man = manifiesto(clinica, "PG-REAL")
    ctx = contexto(clinica)
    salidas, errores = [], []

    def hilo():
        try:
            with Sesion() as db:
                salidas.append(sync_service.ejecutar_lote(db, ctx, man, partes("PG-REAL", contenidos={"PG-REAL": contenido})))
        except BaseException as exc:  # noqa: BLE001
            errores.append(exc)

    hilos = [threading.Thread(target=hilo) for _ in range(2)]
    [h.start() for h in hilos]
    [h.join(60) for h in hilos]
    assert not errores, errores
    resultados = sorted(s["items"][0]["resultado"] for s in salidas)
    assert resultados == ["DUPLICADO", "INCORPORADO"]
    assert contar(Sesion, ResultadoLaboratorio, ResultadoLaboratorio.id_clinica == clinica.id, ResultadoLaboratorio.id_externo == "PG-REAL") == 1
    assert contar(Sesion, DocumentoClinico, DocumentoClinico.id_clinica == clinica.id) == 1
    assert cantidad_de_archivos(almacen) == 1                               # el archivo del perdedor se borró
    assert contar(Sesion, SincronizacionLaboratorio, SincronizacionLaboratorio.id_clinica == clinica.id) == 2
    assert contar(Sesion, SincronizacionLaboratorioItem, SincronizacionLaboratorioItem.id_clinica == clinica.id) == 2


def test_el_fallo_de_un_item_en_postgres_no_deja_filas_ni_documentos_y_no_aborta_el_lote(Sesion, clinica, almacen, monkeypatch):
    original = sync_service._insertar_resultado

    def falla_el_segundo(db, ctx, **kwargs):
        resultado = original(db, ctx, **kwargs)           # inserta resultado + documento + auditoría dentro del SAVEPOINT
        if kwargs["item"].id_externo == "PG-2":
            raise RuntimeError("fallo después de escribir")
        return resultado

    monkeypatch.setattr(sync_service, "_insertar_resultado", falla_el_segundo)
    with Sesion() as db:
        cuerpo = sync_service.ejecutar_lote(
            db, contexto(clinica), manifiesto(clinica, "PG-1", "PG-2", "PG-3"), partes("PG-1", "PG-2", "PG-3")
        )
    por = {i["id_externo"]: i for i in cuerpo["items"]}
    assert por["PG-2"]["codigo_error"] == "ERROR_INTERNO"
    assert por["PG-1"]["resultado"] == "INCORPORADO" and por["PG-3"]["resultado"] == "INCORPORADO"
    assert contar(Sesion, ResultadoLaboratorio, ResultadoLaboratorio.id_clinica == clinica.id) == 2
    assert contar(Sesion, DocumentoClinico, DocumentoClinico.id_clinica == clinica.id) == 2
    assert cantidad_de_archivos(almacen) == 2
