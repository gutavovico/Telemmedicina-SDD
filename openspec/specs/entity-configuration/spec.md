## Purpose
Administrar identidad, dirección registrada, sedes, servicios y horarios generales de la clínica.
## Requirements
### Requirement: Entity administration
The system SHALL limitar lecturas y cambios al administrador activo de la clínica activa autenticada, con transacciones por operación y desactivación lógica.
#### Scenario: Acceso ajeno
- **WHEN** un administrador indica una sede de otra entidad
- **THEN** recibe 404 y la sede conserva sus datos
### Requirement: Institutional identity
The system SHALL validar PNG/JPEG hasta 2 MiB y unicidad global de la dirección normalizada.
#### Scenario: Dirección en uso
- **WHEN** dos entidades registran la misma dirección
- **THEN** solo una la guarda y su activación queda pendiente
### Requirement: Personal administrator appearance
The system SHALL guardar colores hexadecimales para la combinación de clínica y administrador autorizado y aplicar la apariencia exclusivamente a su panel.
#### Scenario: Dos administradores de la misma clínica
- **WHEN** un administrador guarda su apariencia
- **THEN** vuelve a cargarla al iniciar sesión y el otro administrador conserva su propia apariencia
### Requirement: Operational catalog
The system SHALL admitir tarifas decimales de cero a 99999999.99 y múltiples intervalos por sede y día sin solapamiento.
#### Scenario: Intervalos contiguos
- **WHEN** el administrador guarda 08:00–12:00 y 12:00–16:00 para el mismo día
- **THEN** ambos intervalos quedan registrados
