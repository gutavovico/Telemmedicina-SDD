"""CU11 · tarea 2.5: restricciones aplicadas a nivel de base de datos (CHECK, UNIQUE y único parcial).

Cada caso inserta directamente con el ORM, sin pasar por ningún servicio, y espera ``IntegrityError``.
"""
from datetime import date

import pytest
from sqlalchemy.exc import IntegrityError

from app.modules.medical_records.laboratory_results.models import ResultadoLaboratorio
from app.modules.medical_records.laboratory_sync.models import (
    FuenteLaboratorio,
    SincronizacionLaboratorio,
    SincronizacionLaboratorioItem,
)
from cu11_support import (
    Cu11Env,
    resultado_valido,
    seed_clinicas_roles_permisos,
    seed_dominio_basico,
)


@pytest.fixture(scope="module")
def env():
    entorno = Cu11Env()
    entorno.install()
    yield entorno
    entorno.uninstall()


@pytest.fixture()
def datos(env):
    env.reset()
    with env.SessionLocal() as db:
        ids = seed_clinicas_roles_permisos(db)
        base = seed_dominio_basico(db, ids)
        fuente2 = FuenteLaboratorio(id_clinica=1, codigo="LAB-NORTE", nombre="Laboratorio Norte")
        fuente_c2 = FuenteLaboratorio(id_clinica=2, codigo="LAB-CENTRAL", nombre="Central de la clínica 2")
        db.add_all([fuente2, fuente_c2])
        db.commit()
        base.update({"fuente2": fuente2, "fuente_c2": fuente_c2})
        yield base


def _resultado(datos, **cambios):
    """Resultado MANUAL INCORPORADO válido de la clínica 1."""
    base = resultado_valido(
        id_clinica=1,
        id_paciente=datos["pac1"].id_paciente,
        id_examen=datos["examen"].id_examen,
        registrado_por=datos["admin"].id_usuario,
    )
    base.update(cambios)
    return ResultadoLaboratorio(**base)


def _sincronizado(datos, **cambios):
    base = dict(origen="SINCRONIZADO", id_fuente=datos["fuente"].id_fuente, id_externo="EXT-1", hash_archivo="b" * 64)
    base.update(cambios)
    return _resultado(datos, **base)


def _guardar(env, *objetos):
    with env.SessionLocal() as db:
        db.add_all(objetos)
        db.commit()


def _rechaza(env, *objetos):
    with env.SessionLocal() as db:
        db.add_all(objetos)
        with pytest.raises(IntegrityError):
            db.commit()
        db.rollback()


# ------------------------------ resultados_laboratorio ------------------------------ #
def test_resultado_manual_valido_se_guarda(env, datos):
    _guardar(env, _resultado(datos))


def test_incorporado_sin_paciente_es_rechazado(env, datos):
    _rechaza(env, _resultado(datos, id_paciente=None))


def test_incorporado_sin_examen_es_rechazado(env, datos):
    _rechaza(env, _resultado(datos, id_examen=None))


def test_pendiente_con_paciente_es_rechazado(env, datos):
    _rechaza(env, _sincronizado(datos, estado="PENDIENTE_REVISION", id_paciente=datos["pac1"].id_paciente))


def test_pendiente_con_documento_clinico_es_rechazado(env, datos):
    _rechaza(env, _sincronizado(datos, estado="PENDIENTE_REVISION", id_paciente=None, id_documento=7))


def test_pendiente_sin_paciente_ni_documento_ni_examen_es_valido(env, datos):
    _guardar(env, _sincronizado(datos, estado="PENDIENTE_REVISION", id_paciente=None, id_examen=None,
                                motivo_pendiente="PACIENTE_NO_ENCONTRADO",
                                datos_correspondencia={"ci": "999", "codigo_examen": "HEMOGRAMA"}))


@pytest.mark.parametrize("cambios", [
    {"estado": "OTRO"},
    {"origen": "OTRO"},
    {"content_type": "text/html"},
    {"tamano_bytes": 0},
    {"tamano_bytes": 10 * 1024 * 1024 + 1},
])
def test_valores_fuera_de_catalogo_o_tamano_invalido_son_rechazados(env, datos, cambios):
    _rechaza(env, _resultado(datos, **cambios))


def test_tamano_maximo_exacto_es_valido(env, datos):
    _guardar(env, _resultado(datos, tamano_bytes=10 * 1024 * 1024))


@pytest.mark.parametrize("tipo", ["image/jpeg", "image/png", "application/pdf"])
def test_tipos_de_contenido_permitidos(env, datos, tipo):
    _guardar(env, _resultado(datos, content_type=tipo))


def test_sincronizado_sin_id_externo_o_sin_fuente_es_rechazado(env, datos):
    _rechaza(env, _sincronizado(datos, id_externo=None))
    _rechaza(env, _sincronizado(datos, id_fuente=None))


def test_manual_con_fuente_o_id_externo_es_rechazado(env, datos):
    _rechaza(env, _resultado(datos, id_fuente=datos["fuente"].id_fuente))
    _rechaza(env, _resultado(datos, id_externo="EXT-X"))


def test_responsable_es_obligatorio_usuario_o_proceso(env, datos):
    _rechaza(env, _resultado(datos, registrado_por=None, proceso=None))
    _guardar(env, _sincronizado(datos, registrado_por=None, proceso="LOTE_SINCRONIZACION"))


def test_idempotencia_clinica_fuente_id_externo(env, datos):
    _guardar(env, _sincronizado(datos, id_externo="EXT-7", hash_archivo="1" * 64))
    # mismo (clínica, fuente, id_externo) => rechazado, aunque cambie el contenido
    _rechaza(env, _sincronizado(datos, id_externo="EXT-7", hash_archivo="2" * 64))
    # otra fuente de la misma clínica con el mismo id_externo => válido
    _guardar(env, _sincronizado(datos, id_externo="EXT-7", id_fuente=datos["fuente2"].id_fuente, hash_archivo="3" * 64))
    # otra clínica con el mismo id_externo y su propia fuente => válido
    with env.SessionLocal() as db:
        db.add(ResultadoLaboratorio(**resultado_valido(
            id_clinica=2, id_paciente=datos["pac2"].id_paciente, id_examen=datos["examen"].id_examen,
            origen="SINCRONIZADO", id_fuente=datos["fuente_c2"].id_fuente, id_externo="EXT-7",
            hash_archivo="4" * 64, registrado_por=datos["admin"].id_usuario,
        )))
        db.commit()


def test_un_anulado_sigue_ocupando_su_id_externo(env, datos):
    _guardar(env, _sincronizado(datos, id_externo="EXT-A", estado="ANULADO", hash_archivo="5" * 64))
    _rechaza(env, _sincronizado(datos, id_externo="EXT-A", hash_archivo="5" * 64))


def test_duplicado_manual_mismo_paciente_y_hash_mientras_este_incorporado(env, datos):
    _guardar(env, _resultado(datos, hash_archivo="c" * 64))
    _rechaza(env, _resultado(datos, hash_archivo="c" * 64))
    # otro paciente con el mismo archivo => válido
    _guardar(env, _resultado(datos, hash_archivo="c" * 64, id_paciente=datos["pac2"].id_paciente, id_clinica=2))


def test_duplicado_manual_se_permite_tras_anular_el_anterior(env, datos):
    _guardar(env, _resultado(datos, hash_archivo="d" * 64, estado="ANULADO"))
    _guardar(env, _resultado(datos, hash_archivo="d" * 64))


def test_unicidad_manual_no_alcanza_a_los_sincronizados(env, datos):
    _guardar(env, _resultado(datos, hash_archivo="e" * 64))
    _guardar(env, _sincronizado(datos, id_externo="EXT-E", hash_archivo="e" * 64))


# --------------------------------- fuentes_laboratorio ------------------------------- #
def test_fuente_codigo_unico_por_clinica(env, datos):
    _rechaza(env, FuenteLaboratorio(id_clinica=1, codigo="LAB-CENTRAL", nombre="Repetida"))
    # el mismo código existe en la clínica 2 (fixture) y es válido


def test_fuente_activa_solo_si_o_no(env, datos):
    _rechaza(env, FuenteLaboratorio(id_clinica=1, codigo="LAB-X", nombre="Inválida", activa="TAL VEZ"))
    _guardar(env, FuenteLaboratorio(id_clinica=1, codigo="LAB-OFF", nombre="Inactiva", activa="NO"))


# ----------------------------- sincronizaciones_laboratorio -------------------------- #
def _sync(datos, **cambios):
    base = dict(id_clinica=1, id_fuente=datos["fuente"].id_fuente, estado="COMPLETADA",
                id_usuario=datos["admin"].id_usuario)
    base.update(cambios)
    return SincronizacionLaboratorio(**base)


def test_sincronizacion_valida_y_restricciones(env, datos):
    _guardar(env, _sync(datos))
    _guardar(env, _sync(datos, id_usuario=None, proceso="WEBHOOK"))
    _rechaza(env, _sync(datos, estado="TERMINADA"))
    _rechaza(env, _sync(datos, tipo="STREAM"))
    _rechaza(env, _sync(datos, con_error=-1))
    _rechaza(env, _sync(datos, id_usuario=None, proceso=None))


# ------------------------ sincronizaciones_laboratorio_items ------------------------- #
def test_items_unicos_por_sincronizacion_y_resultado_en_catalogo(env, datos):
    with env.SessionLocal() as db:
        sync = _sync(datos)
        db.add(sync)
        db.commit()
        id_sync = sync.id_sincronizacion
    _guardar(env, SincronizacionLaboratorioItem(
        id_sincronizacion=id_sync, id_clinica=1, id_externo="EXT-1", resultado="ERROR",
        codigo_error="ARCHIVO_TIPO_NO_PERMITIDO",
    ))
    _rechaza(env, SincronizacionLaboratorioItem(
        id_sincronizacion=id_sync, id_clinica=1, id_externo="EXT-1", resultado="DUPLICADO",
    ))
    _rechaza(env, SincronizacionLaboratorioItem(
        id_sincronizacion=id_sync, id_clinica=1, id_externo="EXT-2", resultado="PERDIDO",
    ))
    _guardar(env, SincronizacionLaboratorioItem(
        id_sincronizacion=id_sync, id_clinica=1, id_externo="EXT-2", resultado="PENDIENTE_REVISION",
    ))
