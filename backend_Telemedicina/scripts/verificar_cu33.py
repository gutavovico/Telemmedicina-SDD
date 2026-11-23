"""Ejecutar desde la raíz del backend: python scripts/verificar_cu33.py."""
import os
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
from unittest.mock import patch

import pytest
from sqlalchemy import event
from sqlalchemy.engine import Engine


def main():
    root = Path(__file__).resolve().parents[1]
    os.chdir(root)
    sys.path.insert(0, str(root))
    # La aplicación declara settings y storage durante los imports de los tests.
    # Aislar antes de recolectarlos, incluso si alguien instala un .env después.
    system = {k: os.environ[k] for k in ("SystemRoot", "WINDIR", "PATH", "TEMP", "TMP", "HOME", "USERPROFILE")
              if k in os.environ}
    with TemporaryDirectory() as tmp, patch.dict(os.environ, system, clear=True), \
            patch("dotenv.main.DotEnv.dict", return_value={}):
        os.environ.update(STORAGE_LOCAL_DIR=tmp, STORAGE_BACKEND="local", EMAIL_ENABLED="false",
                          SUBSCRIPTION_CYCLE_WORKER_ENABLED="false", BILLING_CU36_WORKER_ENABLED="false",
                          DB_HOST="invalid.test", PYTEST_DISABLE_PLUGIN_AUTOLOAD="1")

        @event.listens_for(Engine, "do_connect")
        def solo_sqlite(dialect, record, args, params):
            if dialect.name != "sqlite":
                raise AssertionError("Las pruebas CU33 solo admiten SQLite efímero")

        def sin_red(name, args):
            # En Windows, asyncio implementa socketpair con dos sockets locales.
            if name == "socket.connect" and args[1][0] in ("127.0.0.1", "::1"):
                return
            if name in ("socket.connect", "socket.getaddrinfo"):
                raise AssertionError("Las pruebas CU33 no permiten conexiones de red")

        sys.addaudithook(sin_red)
        return pytest.main(["-q", "--tb=short",
            "tests/test_cu33_configuracion.py", "tests/test_storage_keys.py",
            "tests/test_cu12_clinical_documents.py", "tests/test_cu12_documentos.py",
            "tests/test_clinicas.py", "tests/test_cu30_tenant_management.py",
            "tests/test_cu05_medical_agenda.py", "tests/test_cu06_specialist_search.py",
            "tests/test_cu08_live_queue.py", "tests/test_cu09_fichas.py",
            "tests/test_cu19_pagos.py"])


if __name__ == "__main__":
    raise SystemExit(main())
