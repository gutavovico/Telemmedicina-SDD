# Contrato de API REST: Pagos y Comprobantes (CU19)

**Versión del Contrato:** 1.0.0 (SaaS Multitenant)  
**Estándar:** OpenAPI 3.1 / RESTful JSON  
**Ruta Base:** `/pagos` (plano) y `/api/v1/pagos`  
**Seguridad Global:** `BearerAuth` (Header `Authorization: Bearer <JWT_ACCESS_TOKEN>`) para endpoints protegidos  
**Encabezado Multitenant:** `X-Tenant-ID: <UUID>`  
**Dominio:** `analytics` / `pagos`  

---

## 1. Convenciones Multitenant y Seguridad

- **Control de Acceso:** Todos los endpoints requieren autenticación JWT válida (`BearerAuth`).
- **Aislamiento por Tenant:** Cada consulta y mutación filtra por `id_clinica` del usuario autenticado. Un usuario no puede consultar, pagar ni descargar comprobantes de citas o pagos de otro tenant.
- **Unicidad:** Un pago pertenece a un usuario dentro de su clínica (`id_clinica`).
- **Códigos HTTP Semánticos:** `200 OK`, `201 Created`, `400 Bad Request`, `401 Unauthorized`, `403 Forbidden`, `404 Not Found`, `409 Conflict`, `422 Unprocessable Entity`.
- **Manejo de Errores:** Respuesta uniforme `{"detail": "<mensaje>"}` mediante `PagoError` (handler registrado en `app/main.py`).

---

## 2. Esquemas de Datos (Data Schemas)

### 2.1 `CheckoutCreate`
```json
{
  "id_cita": 123,
  "canal": "WEB",
  "metodo_pago": "TARJETA"
}
```
- `id_cita`: int, requerido, > 0. Cita o teleconsulta a pagar.
- `canal`: `"WEB"` o `"MOVIL"` (default `"WEB"`). Define las URLs de retorno.
- `metodo_pago`: `"TARJETA"` o `"QR"` (default `"TARJETA"`). Método elegido por el paciente.

---

### 2.2 `CheckoutResponse`
```json
{
  "id_pago": 1,
  "id_usuario": 15,
  "id_cita": 123,
  "monto": 150.00,
  "moneda": "BOB",
  "metodo_pago": "TARJETA",
  "pasarela": "STRIPE",
  "referencia_transaccion": "pi_123...",
  "fecha_pago": null,
  "estado": "PENDIENTE",
  "url_checkout": "https://checkout.stripe.com/...",
  "expira_en": null,
  "created_at": "2026-11-05T10:00:00Z",
  "cita_fecha": "2026-11-05",
  "cita_hora": "09:30",
  "medico_nombre": "Dr. Juan Pérez",
  "especialidad_nombre": "Medicina General",
  "tipo_consulta": "Presencial",
  "comprobante": null,
  "qr_url": "https://backend-telemedicina.onrender.com/pagos/1/qr",
  "qr_payload": "https://backend-telemedicina.onrender.com/pagos/qr/abc123",
  "simulado": false
}
```

---

### 2.3 `PagoResponse`
```json
{
  "id_pago": 1,
  "id_usuario": 15,
  "id_cita": 123,
  "monto": 150.00,
  "moneda": "BOB",
  "metodo_pago": "TARJETA",
  "pasarela": "STRIPE",
  "referencia_transaccion": "pi_123...",
  "fecha_pago": "2026-11-05T10:00:00Z",
  "estado": "PAGADO",
  "url_checkout": "https://checkout.stripe.com/...",
  "expira_en": null,
  "created_at": "2026-11-05T09:30:00Z",
  "cita_fecha": "2026-11-05",
  "cita_hora": "09:30",
  "medico_nombre": "Dr. Juan Pérez",
  "especialidad_nombre": "Medicina General",
  "tipo_consulta": "Presencial",
  "comprobante": {
    "id_comprobante": 1,
    "id_pago": 1,
    "numero_comprobante": "REC-20261105-000001",
    "tipo_comprobante": "RECIBO",
    "fecha_emision": "2026-11-05T10:00:00Z",
    "archivo_url": "https://storage.../comprobante_REC-20261105-000001.pdf",
    "estado": "EMITIDO"
  }
}
```

---

### 2.4 `ComprobanteResponse`
```json
{
  "id_comprobante": 1,
  "id_pago": 1,
  "numero_comprobante": "REC-20261105-000001",
  "tipo_comprobante": "RECIBO",
  "fecha_emision": "2026-11-05T10:00:00Z",
  "archivo_url": "https://storage.../comprobante_REC-20261105-000001.pdf",
  "estado": "EMITIDO"
}
```

---

### 2.5 `CitaPendientePago`
```json
{
  "id_cita": 123,
  "fecha_cita": "2026-11-05",
  "hora_inicio": "09:30",
  "hora_fin": "10:00",
  "medico_nombre": "Dr. Juan Pérez",
  "especialidad_nombre": "Medicina General",
  "tipo_consulta": "Presencial",
  "estado_cita": "PENDIENTE",
  "monto": 150.00,
  "moneda": "BOB",
  "estado_pago": null,
  "id_pago": null
}
```

---

### 2.6 `PagoListResponse`
```json
{
  "total": 5,
  "items": [ /* lista de PagoResponse */ ]
}
```

---

### 2.7 `CitaPendienteListResponse`
```json
{
  "total": 3,
  "items": [ /* lista de CitaPendientePago */ ]
}
```

---

## 3. Endpoints

### 3.1 Endpoints estáticos

#### `GET /estado-pasarela`
Estado de configuración de la pasarela de pagos.

**Respuesta (200):**
```json
{
  "habilitada": true,
  "modo": "STRIPE_SANDBOX",
  "moneda": "BOB",
  "pasarela": "STRIPE"
}
```
- `modo`: `"STRIPE_SANDBOX"` si las credenciales de Stripe están configuradas, `"SIMULADO"` en caso contrario.

#### `POST /checkout`
Crear una sesión de pago (Stripe Checkout) para una cita.

**Request:** `CheckoutCreate`  
**Respuesta (201):** `CheckoutResponse`

#### `GET /pendientes`
Listar citas/teleconsultas pendientes de pago del usuario autenticado.

**Respuesta (200):** `CitaPendienteListResponse`

#### `GET /mis-pagos`
Listar los pagos y comprobantes del usuario autenticado.

**Respuesta (200):** `PagoListResponse`

#### `GET /retorno`
Página de retorno del Checkout en móvil (HTML).

**Query params:** `estado` ("exito" | "cancelado"), `pago` (opcional, id del pago).  
**Respuesta:** HTML (no incluido en OpenAPI schema).

---

### 3.2 Modo demostración (sin credenciales Stripe)

#### `GET /simulado/{qr_token}`
Página de pago simulado para demo local. Solo disponible si Stripe no está habilitado.

#### `POST /simulado/{qr_token}/confirmar`
Confirmar un pago simulado por token QR.

**Respuesta:** HTML (pago registrado, comprobante emitido).

#### `GET /qr/{qr_token}`
Redirección corta usada por el código QR de pago. Redirige (307) a la sesión de Checkout.

---

### 3.3 Webhook

#### `POST /webhook/stripe`
Webhook de confirmación de pagos de Stripe.

**Headers:** `Stripe-Signature`  
**Cuerpo:** payload raw del webhook de Stripe.

---

### 3.4 Endpoints por pago

#### `GET /{id_pago}`
Obtener el detalle de un pago.

**Respuesta (200):** `PagoResponse`

#### `POST /{id_pago}/sincronizar`
Sincronizar el estado del pago con Stripe.

**Respuesta (200):** `PagoResponse`

#### `POST /{id_pago}/simular-pago`
Confirmar un pago en modo demostración.

**Respuesta (200):** `PagoResponse`

#### `GET /{id_pago}/comprobante`
Obtener el comprobante digital de un pago.

**Respuesta (200):** `ComprobanteResponse`

#### `GET /{id_pago}/comprobante/pdf`
Descargar el comprobante digital en PDF.

**Respuesta (200):** `application/pdf` (attachment, filename `<numero_comprobante>.pdf`)

#### `GET /{id_pago}/qr`
Imagen PNG del código QR para pagar la cita.

**Respuesta (200):** `image/png`

---

## 4. Flujo de Pago Confirmado y Push

Tras confirmarse el pago (webhook Stripe, sincronización o simulado), `_finalizar_pago` ejecuta:

1. `db.commit()` — pago marcado como `PAGADO`, cita confirmada si estaba `PENDIENTE`.
2. `db.refresh(pago)`.
3. `notificar_pago_confirmado(db, pago)` — envía push "Pago confirmado" a dispositivos Android activos del usuario. Nunca lanza excepciones; si FCM falla, el pago ya está confirmado y no se revierte.

El push incluye:
- **Título:** `"Pago confirmado"`
- **Cuerpo:** `"Tu pago fue confirmado."` (o `"Tu pago fue confirmado. Comprobante <numero>."`)
- **Data:** `{tipo: "PAGO_CONFIRMADO", id_pago, id_cita, numero_comprobante}`

---

## 5. Variables de Entorno

| Variable | Descripción | Ejemplo |
|---|---|---|
| `STRIPE_SECRET_KEY` | Clave secreta de Stripe | `sk_test_...` |
| `STRIPE_PUBLISHABLE_KEY` | Clave pública de Stripe | `pk_test_...` |
| `STRIPE_WEBHOOK_SECRET` | Secreto del webhook Stripe | `whsec_...` |
| `PAYMENT_PUBLIC_BASE_URL` | URL pública para retornos y QR | `https://backend-telemedicina.onrender.com` |
