# Tasks: CU15 Teleconsulta y Chat de Cita Médica

## [Fase 1: Frontend First - Angular 21 + Tailwind CSS]
- [x] T1.1: Crear archivo de contratos e interfaces TypeScript en `frontend_Telemedicina/src/app/core/models/teleconsulta.models.ts`.
- [x] T1.2: Crear el servicio mock con Signals `TeleconsultaService` con el dataset completo del mockup (Carlos Pérez, Dra. Ana López, Hospital San Juan de Dios).
- [x] T1.3: Maquetar el Navbar superior:
  - Logotipo e identificador de clínica ("Hospital San Juan de Dios").
  - Menú de navegación ("Home", "Mis Citas", "Perfil").
  - Badge de usuario autenticado con avatar circular "CP" y desplegable.
- [x] T1.4: Implementar el encabezado de página: breadcrumb `mis citas` y título dinámico `Consulta: ({paciente.nombreCompleto})`.
- [x] T1.5: Maquetar la Columna Izquierda (Layout Grid):
  - Card "Mis Datos": Avatar azul marino con iniciales blancas, nombre, documento ID, proveedor de seguro y póliza/afiliación.
  - Card "Detalles de la Cita": Médico especialista, especialidad, fechas programadas y hora de teleconsulta ("17:00 h").
- [x] T1.6: Maquetar la Columna Derecha (Card Unificada "Perfil del Médico y Chat"):
  - Encabezado de tarjeta con título `"Perfil del Médico y Chat"`.
  - Bloque superior médico: Foto redondeada, etiqueta `"Su Médico"`, nombre de la doctora y biografía profesional.
  - Separador gráfico estilizado (divisor horizontal tipo píldora).
  - Bloque inferior chat: Cabecera con ícono verde de conversación y etiqueta `"Chatear con el Médico"`.
  - Hilo de mensajes con soporte de autoría (médico a la izquierda con avatar, paciente con estilo propio).
  - Input píldora con placeholder `"Mensaje..."` y botón con ícono de avión de papel para envío.
- [x] T1.7: Conectar el estado reactivo con Signals (`signal()`, `computed()`) para permitir el envío y visualización instantánea (Optimistic UI) de nuevos mensajes en memoria.

---

## [Fase 2: Backend Implementation - FastAPI + SQLAlchemy 2.0]
- [x] T2.1: Diseñar y ejecutar la migración Alembic `009_tablas_chat_cu15.py` en `backend_Telemedicina` con `mensajes_chat_cita` y `citas.id_clinica`.
- [x] T2.2: Implementar modelos SQLAlchemy 2.0 en `backend_Telemedicina/app/modules/communications/models.py`.
- [x] T2.3: Implementar esquemas Pydantic v2 en `backend_Telemedicina/app/modules/communications/schemas.py`.
- [x] T2.4: Implementar `TeleconsultaService` en `backend_Telemedicina/app/modules/communications/service.py`:
  - Consulta agregada que une Paciente, Médico, Especialidad, Cita y Mensajes con filtro obligatorio `id_clinica == tenant_id`.
  - Método de envío de mensajes con validación de membresía a la cita.
- [x] T2.5: Exponer endpoints REST en `router.py`:
  - `GET /api/v1/citas/{id_cita}/teleconsulta` y `GET /api/v1/citas/me/teleconsulta`
  - `POST /api/v1/citas/{id_cita}/chat/mensajes`
- [x] T2.6: Sincronización en tiempo real reactiva integrada mediante polling silencioso periódico y actualización optimista.
- [x] T2.7: Conectar el servicio en Angular `TeleconsultaService` a la API REST del backend con Optimistic UI y reconciliación.

---

## [Fase 3: Mobile Client - Flutter + Clean Architecture]
- [x] T3.1: Definir modelos serializables Dart (`TeleconsultaViewModel`, `ChatMessageModel`) con `fromJson` / `toJson` en `mobile_telemedicina/lib/features/teleconsulta/data/models/`.
- [x] T3.2: Implementar `TeleconsultaRepository` y datasource HTTP consumiendo el endpoint REST `/api/v1/citas/{id_cita}/teleconsulta`.
- [x] T3.3: Implementar `TeleconsultaProvider` (`ChangeNotifier`) para gestión del estado de la cita y el hilo de chat reactivo.
- [x] T3.4: Maquetar la vista móvil responsiva (`TeleconsultaView` / `MisCitasScreen` / `ChatTeleconsultaScreen`):
  - Adaptar las dos columnas del mockup a una vista con scroll continuo o pestañas móviles ("Información de Cita" y "Chat con el Médico").
  - Replicar la estética de las tarjetas de datos, perfil del médico y burbujas de conversación.
  - Implementar caja de texto fija inferior con botón de envío para interacción táctil fluida.
