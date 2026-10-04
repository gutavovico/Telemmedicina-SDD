# Especificación Formal: CU08 Consultar y Actualizar Tiempos de Espera — Live Queue

## 1. Requisitos del Sistema (RFC 2119)

1. El sistema **DEBE** exponer la fila virtual del día por médico derivada de `citas` con `fecha_cita` igual a la fecha solicitada (por defecto hoy, zona UTC-4) y `estado` en (`PENDIENTE`, `CONFIRMADA`, `EN_CURSO`), ordenadas por `hora_inicio` e `id_cita`. Las citas `CANCELADA`, `COMPLETADA`, `ATENDIDA` o `PERDIDA` **NO DEBEN** aparecer en la fila.
2. El paciente autenticado **DEBE** poder consultar `GET /api/v1/cola/mi-turno` y recibir su posición (1 = siendo atendido/siguiente), su ETA en minutos, cuántas citas tiene por delante, el estado de la cola y el nombre del médico, sin recibir datos de ningún otro paciente. Sin cita pendiente hoy, el sistema **DEBE** responder `estado_cola = SIN_TURNOS` y `posicion = 0`.
3. El ETA **DEBE** recalcularse como la suma de `duracion_minutos` de las citas por delante (duración del servicio de cada cita si trae `id_servicio`, si no el promedio del médico, si no 20 minutos por defecto) más los minutos restantes de pausas vigentes que solapen la espera.
4. El médico o recepción **DEBEN** poder registrar pausas, retrasos o imprevistos (`POST /api/v1/cola/pausas` con `id_medico`, `fecha`, `hora_inicio < hora_fin`, `motivo ≥ 3 caracteres`), persistidos como `BloqueoAgenda` en `estado = APROBADO`.
5. El médico o recepción **DEBEN** poder avanzar la fila (`POST /api/v1/cola/{id_cita}/avanzar` marca `ATENDIDA` y pone `EN_CURSO` a la siguiente pendiente) y marcar turnos perdidos (`POST /api/v1/cola/{id_cita}/perdida` marca `PERDIDA` y avanza igual). Cada avance **DEBE** recalcular posiciones y ETAs.
6. Los cambios **DEBEN** reflejarse por sondeo silencioso: web cada 5 segundos y móvil cada 5 segundos, solo con la vista montada, sin spinner en cada refresco.
7. Cuando tras un avance un paciente quede en posición 1 o 2, el sistema **DEBE** crear una `Notificacion` (`tipo = TURNO_PROXIMO`, `estado = PENDIENTE`) a su usuario vinculado (si tiene cuenta) y exponer `proximo = true` en su `mi-turno`.
8. Cada rol **DEBE** ver solo lo necesario: el paciente solo agregados propios; la cola operativa muestra por cita únicamente hora, estado, posición, ETA y nombre del paciente (gestión ya visible en CU25), **nunca** motivo, notas ni datos clínicos. El rol ADMIN de clínica **DEBE** recibir `403 Forbidden` (matriz de roles HU: CU08 excluye al administrador).
9. Con pausa vigente, el sistema **DEBE** responder `estado_cola = PAUSADA` con `mensaje_cola` ("Atención pausada hasta las HH:MM por <motivo>"); con demora acumulada mayor a 30 minutos sin pausa vigente, `estado_cola = DEMORADA` con su mensaje; sin pendientes, `SIN_TURNOS`.
10. La funcionalidad **DEBE** estar disponible en web (Angular) y móvil (Flutter) consumiendo los mismos endpoints.
11. Todo acceso a citas de otra clínica **DEBE** responder `404 Not Found` sin revelar datos; toda cita de paciente ajeno al solicitante, `404`. La interoperabilidad con CU07 **DEBE** cumplirse solo vía `citas`: la cola nunca lee ni escribe `lista_espera`; una cita creada por reasignación CU07 aparece automáticamente en la fila.

---

## 2. Criterios de Aceptación (Gherkin)

```gherkin
Característica: Fila virtual y tiempos de espera (CU08)

  Antecedentes:
    Dado que el médico "Roberto Gómez" tiene hoy 3 citas PENDIENTES a las 09:00, 09:20 y 09:40 en la clínica "Clínica Central"
    Y el paciente "Mateo Valdez" es titular de la cita de las 09:20

  Escenario: Paciente consulta su turno
    Cuando Mateo accede a GET /api/v1/cola/mi-turno
    Entonces responde 200 OK con posicion = 2, delante = 1 y eta_minutos = 20
    Y no contiene nombres ni datos de otros pacientes

  Escenario: Recálculo al avanzar la fila
    Cuando recepción marca POST /api/v1/cola/{id09:00}/avanzar
    Entonces la cita 09:00 queda ATENDIDA y la 09:20 pasa a EN_CURSO
    Y al reconsultar mi-turno Mateo ve posicion = 1 y eta_minutos = 0
    Y se crea una Notificacion TURNO_PROXIMO para Mateo

  Escenario: Pausa con mensaje visible
    Cuando el médico registra una pausa de 10:00 a 10:15 por "Desinfección de consultorio"
    Entonces la cola responde estado_cola = PAUSADA
    Y mensaje_cola contiene "pausada hasta las 10:15"
    Y los ETAs suman los 15 minutos de pausa vigente

  Escenario: Turno perdido reordena
    Cuando se marca PERDIDA la cita de las 09:00
    Entonces Mateo pasa a posicion = 1 sin intervención manual

  Escenario: Restricción multitenant
    Dado que un usuario pertenece a otra clínica
    Cuando consulta la cola del médico de Clínica Central
    Entonces responde 404 Not Found sin revelar datos

  Escenario: Administrador excluido
    Dado un usuario con rol ADMIN de clínica
    Cuando consulta GET /api/v1/cola
    Entonces responde 403 Forbidden

  Escenario: Interoperabilidad con CU07
    Dada una cita creada por reasignación de lista de espera para hoy a las 10:00
    Cuando se consulta la cola operativa
    Entonces la cita de las 10:00 aparece en su posición por hora sin configuración adicional
    Y no existe ninguna lectura a lista_espera
```
