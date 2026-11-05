# Spec Delta

## ADDED Requirements

### Requirement: Acceso móvil administrativo
The system SHALL mostrar Reportes solo a ADMIN con perfil `/auth/me` verificado, estado activo y clínica asignada. SHALL impedir la navegación directa por otros roles, limpiar datos al cambiar de cuenta o cerrar sesión y tratar 401/403 de analytics como rechazo de acceso a reportes. SHALL conservar la sesión para las demás funciones si `/auth/me` sigue aceptando el token.

#### Scenario: Rol ajeno o sesión caducada
- **GIVEN** un perfil Médico, Recepción o Paciente, o un token caducado
- **WHEN** se abre `/analytics` directamente o se consulta el catálogo
- **THEN** la app no muestra resultados protegidos ni ofrece el acceso en Home

#### Scenario: Analytics rechaza una sesión válida
- **GIVEN** una cuenta autenticada cuyo `/auth/me` responde correctamente
- **WHEN** analytics responde 401 o 403
- **THEN** se retiran los datos y el acceso a reportes sin cerrar la sesión válida ni bloquear otras funciones

### Requirement: Constructor y consulta móvil
The system SHALL consumir catálogo y opciones, permitir período, filtros, columnas ordenadas, agrupaciones y criterios de orden según el catálogo, y consultar páginas con la definición normalizada. SHALL distinguir carga, error, vacío y métricas no disponibles; SHALL mostrar ausentismo como «No disponible». SHALL invalidar resultados antiguos cuando cambie la definición.

#### Scenario: Edición y respuesta atrasada
- **GIVEN** un reporte generado y otra consulta aún en vuelo
- **WHEN** ADMIN cambia filtros o columnas
- **THEN** la respuesta antigua no reemplaza el resultado vigente y exportar queda deshabilitado hasta regenerar

#### Scenario: Pacientes únicos
- **GIVEN** agrupaciones de encuentros
- **WHEN** se muestran métricas globales y filas
- **THEN** pacientes únicos globales provienen de `metricas`, sin sumar grupos

### Requirement: Exportación móvil de reportes
The system SHALL enviar la definición normalizada completa a `/analytics/reportes/exportar`, aceptar solo PDF, XLSX, CSV y HTML publicados, validar respuesta binaria/MIME/nombre y ofrecer guardado. SHALL mostrar 413 y no guardar JSON de error como archivo.

#### Scenario: Varias páginas
- **GIVEN** una consulta con más de una página
- **WHEN** ADMIN exporta tras navegar páginas
- **THEN** la solicitud conserva filtros, columnas, agrupación y orden y el backend incluye todos los grupos permitidos
