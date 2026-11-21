"""CU11 · tarea 1.3: convención de la excepción de sesión síncrona de AGENTS.md sección 5.

En los módulos de CU11 está prohibido usar ``.query(...)``, ``AsyncSession`` y ``async def``.
El análisis es sintáctico (``ast``): un docstring o comentario que mencione esas palabras no cuenta.
"""
import ast
from pathlib import Path

import pytest

RAIZ = Path(__file__).resolve().parents[1]
MODULOS_CU11 = (
    RAIZ / "app" / "modules" / "medical_records" / "laboratory_results",
    RAIZ / "app" / "modules" / "medical_records" / "laboratory_sync",
)


def encontrar_violaciones(directorio: Path):
    """Lista ``(archivo, línea, regla)`` de cada uso prohibido en los ``.py`` del directorio."""
    violaciones = []
    for archivo in sorted(directorio.rglob("*.py")):
        arbol = ast.parse(archivo.read_text(encoding="utf-8"), filename=str(archivo))
        for nodo in ast.walk(arbol):
            if isinstance(nodo, ast.AsyncFunctionDef):
                violaciones.append((archivo.name, nodo.lineno, "async def"))
            elif isinstance(nodo, ast.Attribute) and nodo.attr == "query":
                violaciones.append((archivo.name, nodo.lineno, ".query("))
            elif isinstance(nodo, ast.Attribute) and nodo.attr == "AsyncSession":
                violaciones.append((archivo.name, nodo.lineno, "AsyncSession"))
            elif isinstance(nodo, ast.Name) and nodo.id == "AsyncSession":
                violaciones.append((archivo.name, nodo.lineno, "AsyncSession"))
            elif isinstance(nodo, (ast.Import, ast.ImportFrom)):
                for alias in nodo.names:
                    if alias.name.split(".")[-1] == "AsyncSession":
                        violaciones.append((archivo.name, nodo.lineno, "AsyncSession"))
    return violaciones


@pytest.mark.parametrize("directorio", MODULOS_CU11, ids=lambda p: p.name)
def test_modulos_de_cu11_cumplen_la_convencion(directorio):
    assert directorio.is_dir(), f"Falta el módulo {directorio}"
    assert encontrar_violaciones(directorio) == []


def test_el_escaner_detecta_db_query(tmp_path):
    (tmp_path / "servicio.py").write_text(
        "def listar(db, Modelo):\n    return db.query(Modelo).all()\n", encoding="utf-8"
    )
    assert encontrar_violaciones(tmp_path) == [("servicio.py", 2, ".query(")]


def test_el_escaner_detecta_asyncsession_y_async_def(tmp_path):
    (tmp_path / "router.py").write_text(
        "from sqlalchemy.ext.asyncio import AsyncSession\n\n"
        "async def endpoint(db: AsyncSession):\n    return 1\n",
        encoding="utf-8",
    )
    reglas = {regla for _, _, regla in encontrar_violaciones(tmp_path)}
    assert reglas == {"AsyncSession", "async def"}


def test_el_escaner_ignora_docstrings_y_codigo_conforme(tmp_path):
    (tmp_path / "ok.py").write_text(
        '"""Sin session.query() ni AsyncSession: usa select()."""\n'
        "from sqlalchemy import select\n\n"
        "def listar(db, Modelo):\n"
        "    # prohibido db.query(Modelo)\n"
        "    return list(db.execute(select(Modelo)).scalars())\n",
        encoding="utf-8",
    )
    assert encontrar_violaciones(tmp_path) == []
