"""Motor determinista de reglas para detección de interacciones farmacológicas (CU18).

Garantiza farmacovigilancia precisa y reproducible con cero alucinaciones.
"""
import unicodedata
from itertools import combinations
from typing import Dict, List, Optional, Set, Tuple
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.ai_assistant.models import InteraccionCatalogo

# Mapeo canónico de sinónimos comunes a nombres estándar de principio activo
SINONIMOS_PRINCIPIO_ACTIVO: Dict[str, str] = {
    "aspirina": "acido acetilsalicilico",
    "asa": "acido acetilsalicilico",
    "acetaminofen": "paracetamol",
    "acetaminophen": "paracetamol",
    "dipirona": "metamizol",
    "medio de contraste": "medio de contraste yodado",
    "contraste yodado": "medio de contraste yodado",
}

SEVERIDAD_COLOR: Dict[str, str] = {
    "GRAVE": "ROJO",
    "MODERADA": "AMBAR",
    "LEVE": "AZUL",
}


def normalizar_principio_activo(nombre: Optional[str]) -> str:
    """Normaliza un principio activo: minúsculas, sin tildes, sin caracteres extra."""
    if not nombre:
        return ""
    texto = nombre.strip().lower()
    # Eliminar acentos
    texto = unicodedata.normalize("NFKD", texto).encode("ASCII", "ignore").decode("utf-8")
    # Limpieza de puntuación básica
    texto = " ".join(texto.split())
    # Resolver sinónimos
    return SINONIMOS_PRINCIPIO_ACTIVO.get(texto, texto)


class InteraccionDetectada:
    def __init__(
        self,
        principio_activo_1: str,
        principio_activo_2: str,
        medicamento_1_nombre: str,
        medicamento_2_nombre: str,
        severidad: str,
        color_alerta: str,
        mensaje_alerta: str,
        pauta_precaucion: str,
        id_interaccion: Optional[int] = None,
    ):
        self.principio_activo_1 = principio_activo_1
        self.principio_activo_2 = principio_activo_2
        self.medicamento_1_nombre = medicamento_1_nombre
        self.medicamento_2_nombre = medicamento_2_nombre
        self.severidad = severidad
        self.color_alerta = color_alerta
        self.mensaje_alerta = mensaje_alerta
        self.pauta_precaucion = pauta_precaucion
        self.id_interaccion = id_interaccion


def detectar_interacciones(
    db: Session,
    medicamentos: List[Dict[str, str]],
) -> List[InteraccionDetectada]:
    """
    Cruza por pares todos los principios activos presentes en la lista de medicamentos prescritos.
    Cada elemento de medicamentos es un dict con:
      - 'nombre': str
      - 'principio_activo': str
    """
    if len(medicamentos) < 2:
        return []

    # Mapear principios activos normalizados a sus nombres de medicamento
    pa_map: Dict[str, str] = {}
    for med in medicamentos:
        pa_norm = normalizar_principio_activo(med.get("principio_activo") or med.get("nombre"))
        if pa_norm:
            pa_map[pa_norm] = med.get("nombre", pa_norm)

    principios_activos = list(pa_map.keys())
    if len(principios_activos) < 2:
        return []

    # Pares ordenados canónicamente lexicográficamente
    pares_a_consultar: List[Tuple[str, str, str, str]] = []
    for pa, pb in combinations(principios_activos, 2):
        if pa == pb:
            continue
        p1, p2 = (pa, pb) if pa < pb else (pb, pa)
        pares_a_consultar.append((p1, p2, pa, pb))

    alertas: List[InteraccionDetectada] = []
    # Consultar coincidencias en interacciones_catalogo
    for p1, p2, orig_pa, orig_pb in pares_a_consultar:
        stmt = (
            select(InteraccionCatalogo)
            .where(
                InteraccionCatalogo.principio_activo_a == p1,
                InteraccionCatalogo.principio_activo_b == p2,
                InteraccionCatalogo.estado == "ACTIVO",
            )
        )
        interaccion = db.execute(stmt).scalars().first()
        if interaccion:
            sev = interaccion.severidad.upper()
            color = SEVERIDAD_COLOR.get(sev, "AMBAR")
            alertas.append(
                InteraccionDetectada(
                    principio_activo_1=interaccion.principio_activo_a,
                    principio_activo_2=interaccion.principio_activo_b,
                    medicamento_1_nombre=pa_map.get(orig_pa, orig_pa),
                    medicamento_2_nombre=pa_map.get(orig_pb, orig_pb),
                    severidad=sev,
                    color_alerta=color,
                    mensaje_alerta=interaccion.descripcion_riesgo,
                    pauta_precaucion=interaccion.recomendacion_clinica,
                    id_interaccion=interaccion.id_interaccion,
                )
            )

    return alertas


def obtener_recomendaciones_base(
    medicamentos: List[Dict[str, str]],
    diagnosticos: List[str],
    antecedentes: List[str],
) -> List[Dict[str, str]]:
    """Genera recomendaciones base predefinidas ante degradación por fallo de IA."""
    recs: List[Dict[str, str]] = []

    # Pauta universal
    recs.append({
        "categoria": "PRECAUCION_GENERAL",
        "titulo": "Pauta de seguridad clínica base",
        "detalle": "Siga rigurosamente las dosis y horarios prescritos por su médico. Ante cualquier malestar inusual o síntoma adverso, suspenda la automedicación y acuda a consulta.",
        "origen": "REGLA_PREDEFINIDA",
    })

    # Verificar si hay condiciones específicas en antecedentes o diagnósticos
    contexto_str = " ".join(diagnosticos + antecedentes).lower()
    
    if "hipertens" in contexto_str:
        recs.append({
            "categoria": "ESTILO_VIDA",
            "titulo": "Monitoreo de presión arterial",
            "detalle": "Dado su antecedente de hipertensión arterial, controle su presión al menos una vez al día. Evite el consumo excesivo de sodio.",
            "origen": "REGLA_PREDEFINIDA",
        })

    if "gastr" in contexto_str or "ulcera" in contexto_str:
        recs.append({
            "categoria": "HORARIO_ADMINISTRACION",
            "titulo": "Protección gástrica",
            "detalle": "Tome sus medicamentos preferentemente con alimentos o abundante agua para evitar irritación en la mucosa estomacal.",
            "origen": "REGLA_PREDEFINIDA",
        })

    if "diabet" in contexto_str:
        recs.append({
            "categoria": "NUTRICION_HIDRATACION",
            "titulo": "Control glucémico",
            "detalle": "Mantenga horarios fijos de alimentación y registre sus valores de glucemia capilar si está bajo tratamiento hipoglucemiante.",
            "origen": "REGLA_PREDEFINIDA",
        })

    # Recomendación de hidratación
    recs.append({
        "categoria": "NUTRICION_HIDRATACION",
        "titulo": "Hidratación continua",
        "detalle": "Beba abundante agua a lo largo del día para favorecer la distribución y adecuada eliminación metabólica de sus medicamentos.",
        "origen": "REGLA_PREDEFINIDA",
    })

    return recs

