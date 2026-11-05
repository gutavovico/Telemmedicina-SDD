# CU31/CU35 — integración con CU34

El catálogo común es auth.models.VersionPlan (versiones_plan.id BIGINT). Cada
suscripción y pago conserva su propia id_version_plan FK RESTRICT; no se actualiza
por una edición del catálogo. Se retienen columnas y tabla legacy para trazabilidad.
La migración rechaza datos sin mapa explícito, condiciones incompatibles o ciclos
anuales. El operador debe crear una instantánea fiel antes de mapear datos legacy.

Los routers existentes CU31 siguen bajo /api/v1/subscriptions y sus alias actuales.
plan_version_id/id_plan_version de API identifican ahora versiones_plan.id; dinero
es cadena decimal BOB de dos cifras; ciclo MONTHLY (MENSUAL como alias de entrada). No se acepta monto ni entidad
en el body. Los endpoints de administración CU34 siguen exclusivos de superadmin.

CU35: POST /api/v1/subscriptions/quote (plan_version_id); POST
/api/v1/subscriptions/changes (plan_version_id, mode IMMEDIATE|NEXT_CYCLE,
idempotency_key, quote_token para IMMEDIATE); POST /api/v1/subscriptions/cancellation (idempotency_key).
GET /api/v1/subscriptions/changes lista solo las solicitudes de la entidad.
Entradas extra rechazadas; administrador de entidad, 401/403/404/409/422.

Las solicitudes guardan origen, destino, fecha efectiva, importe, actor, versión
de concurrencia y pago asociado. Como máximo una pendiente por suscripción.
Un upgrade pendiente de cobro no altera condiciones ni vigencia. Una confirmación
repetida no cobra ni aplica dos veces. Cambio de ciclo/cancelación mantienen acceso
hasta la fecha efectiva; el proceso de cierre es idempotente y no cobra por sí solo.

Reglas confirmadas: aniversario mensual [inicio,fin), proporcional por segundos
restantes (aritmética Decimal sin float) y HALF_UP, BOB a dos decimales. Mes corto
usa último día y conserva el ancla original; no se recalculan cierres ya pactados.
La cotización firmada dura hasta cinco minutos, identifica entidad, suscripción,
origen/destino y row_version. La solicitud conserva también source_row_version.
Un upgrade exige precio no menor, límites no inferiores y servicios que incluyan
los de origen, con al menos una mejora. El ajuste cero se aplica tras confirmar
la solicitud, sin cobrar. Un pago tardío/incompatible queda REVIEW_REQUIRED.

CU31 renueva manualmente mediante Checkout mode=payment; el retorno del navegador
no confirma pagos. Se verifica firma, sesión, payment_status=paid, BOB e importe
exacto, y se bloquea la suscripción/fila de pago para confirmar una sola vez.
La renovación es explícita y manual. La web muestra la versión publicada vigente
**del mismo plan**, precio mensual BOB, límites y servicios antes de aceptar e
iniciar checkout; el backend exige ese ID publicado al crear el pago. La versión
queda fijada en el pago: una edición posterior no cambia lo aceptado ni cobrado.
Una renovación anticipada pagada no mueve el ciclo actual: el worker aplica la
versión aceptada al inicio del nuevo ciclo. No aceptar o fallar el pago conserva
versión y fechas pagadas; no hay renovación automática ni ciclo gratuito implícito.

Una cancelación pendiente bloquea checkout. Una solicitud NEXT_CYCLE exige el ID
de destino exacto guardado, aun si se publica otra versión después de solicitarla.
GET changes incluye target_version con sus condiciones para revisarlas antes de
pagar. Sin pago, el cierre deja la solicitud WAITING_RENEWAL y conserva el contrato
anterior; el worker no cobra ni extiende vigencia. Un reintento paga ese mismo
periodo acordado; si ya terminó, se requiere conciliación. La fecha efectiva no
se desplaza. Con pago confirmado se aplica ACTIVE desde el inicio acordado y se
conserva el día original de ancla. Las consultas se validan dentro del ciclo de
destino; médicos y sedes son recursos persistentes.

Un pago conserva source_row_version, periodo y application_status: PENDING,
SCHEDULED (pagado, futuro), APPLIED, NOT_APPLIED o REVIEW_REQUIRED. PAGADO prueba
el cobro, no implica por sí solo un contrato aplicado. La sincronización devuelve
application_status, effective_at y application_reason; el historial también
muestra aplicación/revisión. Un pago tardío que contradice una solicitud pendiente
se conserva PAGADO/REVIEW_REQUIRED sin saltarse el cambio o cancelación.

Cancelación solo al cierre pagado; entrada effective_at del cliente rechazada.
Desde esa fecha el backend bloquea los módulos clínicos de esa entidad, incluso
si el worker todavía no procesó su solicitud SCHEDULED. Mantiene login, estado,
historial/comprobantes y datos clínicos. Se reutiliza get_current_user, aplicando
la restricción solo a dominios clínicos; se protegen también las rutas realtime
de CU15 y triaje que antes no solicitaban autenticación. La validación pública
de recetas históricas mantiene su función pública.

Ejecutor: subscription_changes.worker, activado con
SUBSCRIPTION_CYCLE_WORKER_ENABLED=true en un entorno de despliegue ya migrado;
intervalo 60 segundos, bloqueos por entidad y solicitudes idempotentes. Queda
false por defecto y no se activa en pruebas. applied_at registra el instante de
proceso; effective_at mantiene la fecha acordada. El acceso clínico por cancelación
se corta exactamente al vencimiento aun si el proceso se demora.

No se implementa suspensión por consumo/impago CU36. No existe fuente de sedes:
no se inventa consumo cero; una reducción no comprobable se rechaza con
SEDE_USAGE_UNAVAILABLE. Se cuentan médicos activos y consultas HCE registradas
dentro del ciclo. Renovación prepagada impide nuevas solicitudes hasta conciliarla;
no se inventa una política de reembolso.

Cadena integrada: 62b0d532ee0a → cu34_consolidacion_020 →
cu06_servicios_clinica_021 → cu35_integracion_022. La rama CU18 compartida termina
en merge_cu18_asistencia_022 (padres cu18_asistencia_017 y cu06_servicios_clinica_021).
Ambas convergen en cu35_cu18_convergencia_023, única cabecera, sin operaciones DDL.
Las revisiones de main se
conservan byte por byte. Las revisiones locales anteriores CU31/CU35 quedan fuera
de la entrega. Alembic online bloquea antes de 020 si encuentra plan_versions;
no se ejecuta su backfill por nombre sobre datos legacy.

Si 020 ya estaba aplicada, 022 exige subscription_version_map y
payment_version_map por ID de fila para cualquier referencia legacy; valida
importes/moneda/límites y conserva la evidencia anterior de mappings. También
requiere billing_anchor_map para suscripciones existentes y plan_version_map
para referencias antiguas de clínica/solicitud. Sin snapshot verificable se
detiene, nunca genera correspondencias por nombre ni borra historial.

Persistencia canónica: id_version_plan (FK a versiones_plan.id), no una segunda
columna version_plan_id. API mantiene plan_version_id de entrada y ambos
plan_version_id/id_plan_version de salida para compatibilidad CU31. Se conserva
MONTHLY en persistencia y API CU31; MENSUAL es alias de entrada y ciclo de los
snapshots CU34. Ambos significan exclusivamente mensual; ANNUAL se rechaza.

El destino Neon inspeccionado solo en lectura está en merge_cu18_asistencia_022,
recuperada de origin/main en d952a29cfe33a1f30aed41535ab40ec886b26efc.
La suscripción y pago observados ya referencian la misma versión canónica; no
necesitan correspondencia por nombre. Su ancla original no está acreditada por
el esquema/historial disponible: no deducirla de fecha_inicio. La actualización
se detiene sin billing_anchor_map verificado; una renovación de suscripción
existente sin ancla responde 409. La prueba poblada local usa un ancla ficticia
explícita y no constituye aprobación de un mapa para la base compartida.
Las pruebas locales no autorizan stamp ni reescritura de revisiones compartidas.
