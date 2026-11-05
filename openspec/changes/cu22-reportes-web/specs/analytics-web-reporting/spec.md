# Spec Delta

## Purpose

Permite a un administrador construir y revisar reportes clínicos y administrativos en la web usando exclusivamente las definiciones autorizadas del contrato CU22.

## ADDED Requirements

### Requirement: Acceso web exclusivo de ADMIN
The system SHALL mostrar navegación y pantalla de reportes solo a un usuario con sesión verificada, rol administrativo textual, estado activo y clínica asignada; SHALL esperar el perfil de sesión antes de resolver navegación directa. SHALL tratar 401 y 403 de analytics como rechazo de acceso y no mostrar datos protegidos.

#### Scenario: Navegación directa con rol ajeno
- **GIVEN** una sesión cuyo perfil `/auth/me` indica `MEDICO` o un rol desconocido
- **WHEN** se navega directamente a `/analitica`
- **THEN** el guard impide la pantalla de reportes y la navegación no ofrece su enlace

#### Scenario: Perfil aún en carga
- **GIVEN** un token almacenado y un perfil local que todavía no fue revalidado
- **WHEN** se intenta abrir `/analitica`
- **THEN** la decisión espera el resultado del perfil fresco y no concede acceso por datos locales anteriores

### Requirement: Constructor validado de reportes
The system SHALL cargar tipos, dimensiones, métricas, filtros, operadores, modalidades y límites desde `GET /analytics/reportes/catalogo`, y médicos/especialidades desde `GET /analytics/reportes/opciones`. SHALL permitir período, filtros, columnas en orden, agrupación y orden de filas; SHALL rechazar antes de consultar fechas invertidas, período mayor a 366 días y combinaciones incompatibles con el catálogo. SHALL omitir `id_clinica` del cuerpo.

#### Scenario: Cambio de tipo y limpieza de configuración
- **GIVEN** columnas, agrupación y filtros de un reporte de citas
- **WHEN** ADMIN cambia a encuentros
- **THEN** la interfaz quita los campos incompatibles y exige una definición válida antes de consultar

#### Scenario: Fecha o combinación inválida
- **GIVEN** un período invertido o una dimensión seleccionada sin columna compatible
- **WHEN** ADMIN intenta generar
- **THEN** se muestra el error y no se envía `POST /analytics/reportes/consulta`

### Requirement: Resultados normalizados y estado de consulta
The system SHALL presentar la definición normalizada, métricas globales con disponibilidad, advertencias, fecha de generación, filas y total de grupos de `POST /analytics/reportes/consulta`. SHALL distinguir carga, error y cero registros, paginar con la definición generada y evitar que respuestas antiguas sobrescriban resultados nuevos. SHALL mostrar ausentismo como no disponible, sin porcentaje ficticio, y SHALL usar el total global de pacientes únicos sin sumar grupos.

#### Scenario: Respuesta obsoleta y consulta vacía
- **GIVEN** dos consultas sucesivas, la primera más lenta, o un resultado con `total=0`
- **WHEN** llega una respuesta tardía o vacía
- **THEN** la respuesta antigua no reemplaza la reciente y el estado vacío no se confunde con métrica no disponible

#### Scenario: Edición después de generar
- **GIVEN** un reporte generado y visible
- **WHEN** ADMIN modifica filtros, columnas, grupos u orden
- **THEN** la interfaz indica que debe generar de nuevo y bloquea exportar la configuración modificada

### Requirement: Presentación accesible y adaptable
The system SHALL conservar Header/Footer y el sistema visual existente, presentar filtros, indicadores y tabla sin desbordamiento de página y ofrecer etiquetas, foco visible y controles utilizables en escritorio y móvil. SHALL omitir controles de voz, texto libre o eMail sin servicio real.

#### Scenario: Pantalla pequeña
- **GIVEN** un ancho móvil y un reporte de seis columnas
- **WHEN** ADMIN revisa los resultados
- **THEN** la tabla desplaza horizontalmente dentro de su contenedor sin desbordar la página
