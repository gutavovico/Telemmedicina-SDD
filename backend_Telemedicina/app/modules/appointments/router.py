from fastapi import APIRouter
from app.modules.appointments.doctor_entity_links.router import (
    router as doctor_entity_links_router,
)
from app.modules.appointments.doctor_profile.router import (
    router as doctor_profile_router,
    router_especialidades,
)
from app.modules.appointments.agenda.router import router as agenda_router
from app.modules.appointments.consultas.router import router as consultas_router
from app.modules.appointments.live_queue.router import router as live_queue_router
from app.modules.appointments.lista_espera.router import router as lista_espera_router
from app.modules.appointments.specialist_search.router import router as specialist_search_router

router = APIRouter()

# 0. CU29 antes de /medicos/{id_medico}: /medicos/vinculaciones es literal.
router.include_router(doctor_entity_links_router)
router.include_router(doctor_entity_links_router, prefix="/api/v1")


# 1. Rutas principales de Médicos (/medicos, /appointments/medicos y /api/v1/medicos)
router.include_router(doctor_profile_router)
router.include_router(doctor_profile_router, prefix="/appointments")
router.include_router(doctor_profile_router, prefix="/api/v1")

# 2. Rutas del Catálogo de Especialidades (/especialidades, /appointments/especialidades y /api/v1/especialidades)
router.include_router(router_especialidades)
router.include_router(router_especialidades, prefix="/appointments")
router.include_router(router_especialidades, prefix="/api/v1")

# 3. Rutas de Agenda Médica (CU05)
router.include_router(agenda_router)
router.include_router(agenda_router, prefix="/api/v1")

# 3b. Fila virtual y tiempos de espera (CU08): /cola y /api/v1/cola
router.include_router(live_queue_router)
router.include_router(live_queue_router, prefix="/api/v1")

# 3b-bis. Lista de espera y reasignacion de cupos (CU07): /lista-espera y /api/v1/lista-espera
router.include_router(lista_espera_router)
router.include_router(lista_espera_router, prefix="/api/v1")

# 3c. Búsqueda de Especialistas y Disponibilidad (CU06): /especialistas y /api/v1/especialistas
router.include_router(specialist_search_router)
router.include_router(specialist_search_router, prefix="/api/v1")

# 4. Rutas de Consultas y Citas Médicas (CU25)
router.include_router(consultas_router, prefix="/appointments/consultas")
router.include_router(consultas_router, prefix="/citas")
router.include_router(consultas_router, prefix="/appointments/citas")
router.include_router(consultas_router, prefix="/api/v1/citas")
