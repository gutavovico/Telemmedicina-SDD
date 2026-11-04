# Contract: CU31 Subscription Payments

Base `/api/v1`, authenticated tenant ADMIN only. Tenant comes from JWT/header context.

## Endpoints

- `GET /subscriptions/current` → subscription summary, plan version, cycle, limits, period, derived status.
- `GET /subscriptions/plans` → active plan versions and MONTHLY/ANNUAL prices.
- `POST /subscriptions/checkout` body `{ "plan_version_id": "uuid", "cycle": "MONTHLY|ANNUAL" }` → 201 payment, amount, currency, checkout_url, expires_at. No amount/card/tenant fields accepted.
- `GET /subscription-payments?page=1&per_page=20` → tenant payment history.
- `GET /subscription-payments/{id}/receipt` → receipt metadata.
- `GET /subscription-payments/{id}/receipt/pdf` → application/pdf.
- `POST /payments/webhook/stripe` → signed, idempotent provider callback (existing route may be reused if routing distinguishes payment type).

States: subscription `TRIALING|ACTIVE|PAST_DUE|EXPIRED|CANCELLED`; payment `PENDING|PAGADO|FALLIDO|CANCELADO`. Errors: 401, 403, 404, 409, 422.