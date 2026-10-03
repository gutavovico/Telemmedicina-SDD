# Especificación Formal: CU15 Teleconsulta y Chat de Cita Médica

## 1. Requisitos del Sistema (RFC 2119)

1. El sistema **DEBE** renderizar la vista de teleconsulta únicamente a usuarios autenticados que pertenezcan al mismo `tenant_id` (`id_clinica`) asociado a la cita.
2. La vista **DEBE** mostrar en el encabezado superior el nombre de la clínica a la que pertenece el usuario ("Hospital San Juan de Dios"), los accesos de navegación y el avatar con iniciales del usuario en sesión.
3. El sistema **DEBE** presentar la ruta de navegación (breadcrumb) `mis citas` y el título `Consulta: ({nombre_paciente})` reflejando el paciente seleccionado.
4. La tarjeta "Mis Datos" **DEBE** exhibir el avatar circular con las iniciales del paciente, nombre completo, documento de identificación oficial y los datos de afiliación médica (`seguroProveedor` y `seguroPoliza`).
5. La columna derecha **DEBE** estar unificada en un único contenedor titulado `"Perfil del Médico y Chat"` conteniendo el perfil del especialista, un divisor visual tipo píldora y el submódulo de mensajería con la cabecera `"Chatear con el Médico"`.
6. Al enviar un mensaje, la interfaz **DEBE** incorporarlo inmediatamente al hilo visual (Optimistic UI) y persistirlo en la base de datos vinculado a la cita médica.

---

## 2. Criterios de Aceptación (Gherkin)

```gherkin
Característica: Vista de Teleconsulta y Chat de Cita Médica (CU15)

  Antecedentes:
    Dado que el paciente "Carlos Pérez" con identificación "12345678X" está autenticado en la clínica "Hospital San Juan de Dios"
    Y tiene una cita de teleconsulta confirmada con ID 105 asignada a la "Dra. Ana López"

  Escenario: Visualización exitosa y fiel de la vista de teleconsulta según mockup
    Cuando el paciente accede a la ruta de la cita "/citas/105/teleconsulta"
    Entonces el encabezado de navegación debe mostrar "Hospital San Juan de Dios" y el badge de usuario "carlos perez"
    Y la página debe mostrar el breadcrumb "mis citas"
    Y el título principal debe ser exactamente "Consulta: (Carlos Pérez)"
    Y la tarjeta "Mis Datos" debe contener:
      | Campo            | Valor         |
      | Avatar           | CP            |
      | Nombre           | Carlos Pérez  |
      | Identificación ID| 12345678X     |
      | Seguro Proveedor | Sanitas Plus  |
      | Seguro Póliza    | Sanitas Plus  |
    Y la tarjeta "Detalles de la Cita" debe mostrar la especialidad "Medicina General" y hora "17:00 h"
    Y el contenedor derecho unificado "Perfil del Médico y Chat" debe mostrar:
      | Sección          | Contenido                                         |
      | Título de Card   | Perfil del Médico y Chat                          |
      | Subtítulo Médico | Su Médico                                         |
      | Nombre Especial. | Dra. Ana López                                    |
      | Subheader Chat   | Chatear con el Médico                             |
    Y el historial de mensajes debe presentar el mensaje previo de la doctora con estampa "17:00 h"

  Escenario: Envío de mensaje en el chat médico
    Dado que la caja de texto del chat muestra el placeholder "Mensaje..."
    Cuando el paciente escribe "Buenas tardes doctora, ya tengo a mano mis estudios"
    Y hace clic en el botón de envío
    Entonces el mensaje debe aparecer de forma inmediata en el historial de chat
    Y el campo de texto debe quedar limpio
    Y el sistema debe enviar la solicitud de persistencia asociada al ID de cita 105

  Escenario: Restricción de acceso multitenant
    Dado que un usuario intenta consultar la teleconsulta con ID 105
    Pero dicho usuario pertenece a una clínica diferente al tenant de la cita
    Cuando se procesa la solicitud
    Entonces el backend debe responder con código de estado 404 Not Found
    Y ningún dato clínico ni mensaje debe ser revelado
```
