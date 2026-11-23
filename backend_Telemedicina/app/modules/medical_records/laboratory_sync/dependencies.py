"""Dependencias de la sincronización de laboratorio (CU11, bloque B).

Reutiliza la resolución estricta de la clínica de la sesión y el verificador de permisos de
``laboratory_results``: la clínica sale SIEMPRE de ``Usuario.id_clinica`` (nunca de body, query ni
``X-Tenant-ID``) y toda la gestión de fuentes y sincronizaciones exige ``lab_results:sync``.
"""
from app.modules.medical_records.laboratory_results.dependencies import (  # noqa: F401
    PERMISO_SYNC,
    Contexto,
    requerir_permisos,
)

requerir_sync = requerir_permisos(PERMISO_SYNC)
