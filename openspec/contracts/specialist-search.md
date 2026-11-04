# Contract: CU06 Specialist Search

Base: `/api/v1`. Tenant: claim JWT `tenant_id` (precedence) or `X-Tenant-ID` UUID. Never accept tenant id in query/body.

## GET /especialistas/buscar

Query: `nombre?`, `especialidad_id?`, `modalidad=PRESENCIAL|TELECONSULTA|AMBAS`, `costo_min?`, `costo_max?`, `fecha_inicio`, `fecha_fin`, `page=1`, `per_page=20`.

```json
{
  "total": 1,
  "page": 1,
  "per_page": 20,
  "items": [{
    "id_medico": 42,
    "nombre_completo": "Dra. Elena Ríos Vargas",
    "foto_url": null,
    "matricula_profesional": "MAT-20381",
    "especialidades": [{"id_especialidad": 2, "nombre": "Pediatría"}],
    "servicios": [{
      "id_servicio": 7,
      "nombre": "Teleconsulta pediátrica",
      "modalidad": "TELECONSULTA",
      "costo": 250.00,
      "moneda": "BOB",
      "duracion_minutos": 30
    }],
    "disponibilidad": [{
      "fecha": "2026-04-10",
      "slots": [{"hora_inicio": "08:00:00", "hora_fin": "08:30:00", "disponible": true}]
    }]
  }]
}
```

Errors: 401 unauthenticated, 403 invalid/insufficient tenant context, 422 invalid filters/date range, 404 professional absent only on detail.

## GET /especialistas/{id_medico}/disponibilidad

Query: `fecha_inicio`, `fecha_fin`, optional `id_servicio`. Maximum 31 days. Returns professional summary, services and availability array. Cross-tenant id returns 404.