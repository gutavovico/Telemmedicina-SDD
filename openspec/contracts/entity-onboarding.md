# Contract: CU32 Health Entity Onboarding

## Public onboarding

`POST /api/v1/public/tenant-requests` multipart fields: `nombre`, `razon_social`, `nit`, `correo`, `telefono`, `direccion`, `responsable_nombre`, `responsable_correo`, `responsable_telefono`, `plan_version_id`, `documentos[]`. Response 202: `{ "id_request": "uuid", "tracking_code": "opaque", "status": "PENDING" }`. Duplicate normalized NIT returns 409.

`GET /api/v1/public/tenant-requests/{tracking_code}` → `{ "institucion", "status", "mensaje", "fecha_decision?" }`; invalid code returns 404.

## Tenant deactivation

`POST /api/v1/tenant/deactivation-requests` authenticated tenant ADMIN body `{ "motivo": "…" }` → 202 request in PENDING. Does not delete tenant or clinical data.

States: request `PENDING|APPROVED|REJECTED`; deactivation `PENDING|APPROVED|REJECTED|CANCELLED`. Errors: 409 duplicate/state conflict, 413 file too large, 422 validation.