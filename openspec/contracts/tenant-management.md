# Contract: CU30 Tenant Management

Global backoffice, Super Administrator only. No `X-Tenant-ID` required. Mutations require `row_version` (or `If-Match`).

## Requests

- `GET /api/v1/tenant-requests?status=PENDING&page=1&per_page=20`
- `GET /api/v1/tenant-requests/{id_request}` → institutional snapshot, representative, requested plan, documents, status, decision metadata.
- `POST /api/v1/tenant-requests/{id_request}/approve` body `{ "row_version": 1 }`.
- `POST /api/v1/tenant-requests/{id_request}/reject` body `{ "reason": "…", "row_version": 1 }`.

## Tenants

- `GET /api/v1/tenants?status=ACTIVE&page=1&per_page=20`
- `GET /api/v1/tenants/{tenant_id}`.
- `POST /api/v1/tenants/{tenant_id}/activate` body `{ "reason", "row_version" }`.
- `POST /api/v1/tenants/{tenant_id}/suspend` body `{ "reason", "row_version" }`.
- `POST /api/v1/tenants/{tenant_id}/reactivate` body `{ "reason", "row_version" }`.
- `POST /api/v1/tenants/{tenant_id}/deactivate` body `{ "reason", "row_version" }`.
- `PUT /api/v1/tenants/{tenant_id}/commercial-agreement` body `{ "plan_id", "commercial_notes", "row_version" }`.

Statuses: request `PENDING|APPROVED|REJECTED`; tenant `ACTIVE|SUSPENDED|INACTIVE`. Errors: 401, 403, 404, 409 stale version, 422 validation.